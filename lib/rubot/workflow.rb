# frozen_string_literal: true

module Rubot
  # Public API: subclass Rubot::Workflow for ordered orchestration.
  # Stable subclass hooks are the step DSL and instance step methods.
  # Resume/checkpoint internals remain framework-owned.
  class Workflow
    extend DSL

    class InputMapping
      attr_reader :description, :metadata

      def initialize(description, metadata: nil, &resolver)
        @description = description
        @metadata = metadata
        @resolver = resolver
      end

      def call(input, state, context)
        @resolver.call(input, state, context)
      end

      def inspect
        "#<Rubot::Workflow::InputMapping #{description}>"
      end
    end

    class OutputMapping
      attr_reader :description

      def initialize(description, &resolver)
        @description = description
        @resolver = resolver
      end

      def call(workflow)
        @resolver.call(workflow)
      end

      def inspect
        "#<Rubot::Workflow::OutputMapping #{description}>"
      end
    end

    class << self
      def flow_graph
        Rubot::FlowVisualization::Builder.for_workflow(self)
      end

      def flow_mermaid
        flow_graph.to_mermaid
      end

      def rubot_operation_owner
        @rubot_operation_owner
      end

      def from_input(*keys)
        build_input_mapping(:input, *keys)
      end

      def from_state(*keys)
        build_input_mapping(:state, *keys)
      end

      def from_context(*keys)
        build_input_mapping(:context, *keys)
      end

      def slice(source, *keys)
        mapping = normalize_input_mapping(source)

        InputMapping.new("slice(#{mapping.description}, #{format_keys(keys)})", metadata: { kind: :slice, source: mapping.metadata, keys: keys.map(&:to_sym) }) do |input, state, context|
          value = mapping.call(input, state, context)
          raise ValidationError, "Workflow input helper slice source must resolve to a mapping" unless value.is_a?(Hash)

          value.slice(*keys)
        end
      end

      def merge(*sources)
        normalized_sources = sources.map { |source| normalize_merge_source(source) }
        descriptions = normalized_sources.map { |source| source[:description] }
        metadata_sources = normalized_sources.filter_map { |source| source[:metadata] }

        InputMapping.new(
          "merge(#{descriptions.join(', ')})",
          metadata: { kind: :merge, sources: metadata_sources }
        ) do |input, state, context|
          normalized_sources.each_with_object({}) do |source, memo|
            value = source[:resolver].call(input, state, context)
            next if value.nil?

            raise ValidationError, "Workflow input helper merge sources must resolve to mappings" unless value.is_a?(Hash)

            memo.merge!(value)
          end
        end
      end

      def output(*keys, &block)
        return @rubot_output_mapping if keys.empty? && !block

        @rubot_output_mapping =
          if block
            OutputMapping.new("output { ... }") do |workflow|
              workflow.instance_exec(workflow.run.input, workflow.run.state, workflow.run.context, workflow.run, &block)
            end
          elsif keys.length == 1
            key = keys.first
            OutputMapping.new("output(#{key.inspect})") { |workflow| workflow.run.state.fetch(key) }
          else
            OutputMapping.new("output(#{format_keys(keys)})") { |workflow| workflow.run.state.slice(*keys) }
          end
      end

      def rubot_output_mapping
        @rubot_output_mapping
      end

      def step(name, **options, &block)
        rubot_steps << StepDefinition.new(kind: :step, name:, options:, block:)
      end

      def tool_step(name, tool:, input: nil, save_as: nil, **options)
        rubot_steps << StepDefinition.new(
          kind: :tool_step,
          name:,
          options: options.merge(tool: tool, input:, save_as:)
        )
      end

      def agent_step(name, agent:, input: nil, save_as: nil, **options)
        rubot_steps << StepDefinition.new(
          kind: :agent_step,
          name:,
          options: options.merge(agent: agent, input:, save_as:)
        )
      end

      def approval_step(name, role: nil, reason: nil, assigned_to: nil, sla_seconds: nil, expires_in: nil, **options)
        rubot_steps << StepDefinition.new(
          kind: :approval_step,
          name:,
          options: options.merge(role:, reason:, assigned_to:, sla_seconds:, expires_in:)
        )
      end

      def compute(name, **options, &block)
        rubot_steps << StepDefinition.new(kind: :compute, name:, options:, block:)
      end

      def choice(name, **options, &block)
        rubot_steps << StepDefinition.new(kind: :choice, name:, options:, block:)
      end

      def on_failure(handler = nil, &block)
        @rubot_failure_handler = handler || block
      end

      def rubot_failure_handler
        @rubot_failure_handler
      end

      private

      def build_input_mapping(source, *keys)
        InputMapping.new(
          helper_description(source, keys),
          metadata: { kind: :source, source: source, keys: keys.map(&:to_sym).presence }
        ) do |input, state, context|
          value = source_value(source, input, state, context)

          if keys.empty?
            value
          elsif source == :state && keys.length == 1
            value.fetch(keys.first)
          else
            value.slice(*keys)
          end
        end
      end

      def source_value(source, input, state, context)
        case source
        when :input then input
        when :state then state
        when :context then context
        else
          raise ValidationError, "Unsupported workflow input source #{source.inspect}"
        end
      end

      def normalize_input_mapping(source)
        case source
        when InputMapping
          source
        when Proc
          InputMapping.new("proc", metadata: { kind: :proc }) { |input, state, context| source.call(input, state, context) }
        when :input
          from_input
        when :state
          from_state
        when :context
          from_context
        else
          raise ValidationError, "Workflow input helper source must be :input, :state, :context, a helper, or a Proc"
        end
      end

      def normalize_merge_source(source)
        case source
        when Hash
          {
            description: source.inspect,
            metadata: { kind: :literal },
            resolver: ->(_input, _state, _context) { source }
          }
        else
          mapping = normalize_input_mapping(source)
          {
            description: mapping.description,
            metadata: mapping.metadata,
            resolver: ->(input, state, context) { mapping.call(input, state, context) }
          }
        end
      end

      def helper_description(source, keys)
        return "from_#{source}" if keys.empty?

        "from_#{source}(#{format_keys(keys)})"
      end

      def format_keys(keys)
        keys.map(&:inspect).join(", ")
      end

      public

      def resolve_operation_tool(tool)
        return tool unless tool.is_a?(Symbol)

        owner = rubot_operation_owner
        return tool unless owner.respond_to?(:tool)

        owner.tool(tool) || raise(ExecutionError, "#{name} could not resolve tool #{tool} from #{owner.name}")
      end

      def resolve_operation_agent(agent)
        return agent unless agent.is_a?(Symbol)

        owner = rubot_operation_owner
        return agent unless owner.respond_to?(:agent)

        owner.agent(agent) || raise(ExecutionError, "#{name} could not resolve agent #{agent} from #{owner.name}")
      end
    end

    def initialize(run:)
      @run = run
      @step_index = 0
      @jump_target = nil
      @skip_target = nil
    end

    attr_reader :run

    def jump_to(step_name)
      @jump_target = step_name.to_sym
    end

    def skip_to(step_name)
      @skip_target = step_name.to_sym
    end

    def execute
      @step_index = 0
      run_loop
    end

    def resume
      @step_index = resume_index + 1
      run_loop
    end

    private

    def run_loop
      steps = self.class.rubot_steps
      while @step_index < steps.size
        step_definition = steps[@step_index]
        @jump_target = nil
        @skip_target = nil

        run.raise_if_canceled!

        if step_definition.condition_met?(self)
          run.current_step = step_definition.name
          run.add_event(Event.new(type: "step.entered", step_name: step_definition.name))
          result = execute_or_resume_step(step_definition)

          if @jump_target
            handle_jump(@jump_target)
            next
          elsif @skip_target
            handle_skip(@skip_target)
            next
          end

          checkpoint_step(step_definition, result) unless run.waiting_for_approval?
          run.add_event(Event.new(type: "step.exited", step_name: step_definition.name, payload: { result: result })) unless run.waiting_for_approval?
          return run if run.waiting_for_approval? || run.failed?
        end

        @step_index += 1
      end

      run.complete!(final_output)
    rescue StandardError => e
      handle_failure(e)
      raise
    end

    def handle_jump(target)
      index = self.class.rubot_steps.find_index { |step| step.name == target }
      raise ExecutionError, "Jump target #{target} not found" unless index

      clear_checkpoints_from(index)
      @step_index = index
    end

    def handle_skip(target)
      index = self.class.rubot_steps.find_index { |step| step.name == target }
      raise ExecutionError, "Skip target #{target} not found" unless index

      clear_checkpoints_from(index)
      @step_index = index
    end

    def clear_checkpoints_from(index)
      self.class.rubot_steps[index..].each do |step|
        run.clear_checkpoint!(step.name)
      end
    end

    def execute_or_resume_step(step_definition)
      if run.step_completed?(step_definition.name)
        run.add_event(
          Event.new(
            type: "step.resumed_from_checkpoint",
            step_name: step_definition.name,
            payload: { checkpoint: run.checkpoint_for(step_definition.name) }
          )
        )
        return checkpoint_output(step_definition)
      end

      execute_step(step_definition)
    end

    def execute_step(step_definition)
      case step_definition.kind
      when :step
        step_definition.block ? instance_exec(run.input, run.state, run.context, &step_definition.block) : public_send(step_definition.name)
      when :tool_step
        execute_tool_step(step_definition)
      when :agent_step
        execute_agent_step(step_definition)
      when :approval_step
        execute_approval_step(step_definition)
      when :compute, :choice
        instance_exec(run.input, run.state, run.context, &step_definition.block)
      else
        raise ExecutionError, "Unsupported step kind #{step_definition.kind}"
      end
    end

    def execute_tool_step(step_definition)
      tool_class = self.class.resolve_operation_tool(step_definition.options.fetch(:tool))
      input = resolve_input(step_definition.options[:input])
      output = tool_class.new.execute(input:, run:)
      persist_step_output(step_definition, output)
      output
    end

    def execute_agent_step(step_definition)
      agent_class = self.class.resolve_operation_agent(step_definition.options.fetch(:agent))
      input = resolve_input(step_definition.options[:input])
      run.add_event(Event.new(type: "agent.started", step_name: step_definition.name, payload: { agent_name: agent_class.name, input: input }))
      output = agent_class.run(input:, run:, context: run.context)
      persist_step_output(step_definition, output)
      output
    end

    def execute_approval_step(step_definition)
      approval = run.pending_approval
      approved_approval = run.approvals.reverse.find do |item|
        item.step_name == step_definition.name.to_s && item.status == :approved
      end

      if approved_approval
        run.add_event(Event.new(type: "approval.granted", step_name: step_definition.name, payload: approved_approval.to_h))
        return approved_approval.decision_payload
      end

      if approval && approval.step_name == step_definition.name.to_s && approval.status == :approved
        run.add_event(Event.new(type: "approval.granted", step_name: step_definition.name, payload: approval.to_h))
        return approval.decision_payload
      end

      approval ||= Approval.new(
        step_name: step_definition.name.to_s,
        role_requirement: step_definition.options[:role],
        reason: step_definition.options[:reason],
        assigned_to: resolve_approval_assignment(step_definition.options[:assigned_to]),
        sla_due_at: resolve_relative_time(step_definition.options[:sla_seconds]),
        expires_at: resolve_relative_time(step_definition.options[:expires_in])
      )
      run.add_approval(approval) unless run.approvals.include?(approval)
      run.wait_for_approval!
      run.checkpoint!(step_name: step_definition.name, kind: step_definition.kind, status: :waiting_for_approval, payload: approval.to_h)
      run.add_event(Event.new(type: "approval.requested", step_name: step_definition.name, payload: approval.to_h))
      nil
    end

    def resolve_input(input)
      case input
      when InputMapping
        input.call(run.input, run.state, run.context)
      when Proc
        instance_exec(run.input, run.state, run.context, &input)
      when Symbol
        run.state.fetch(input)
      when NilClass
        run.input
      else
        input
      end
    end

    def persist_step_output(step_definition, output)
      key = step_definition.options[:save_as] || step_definition.name
      run.state[key] = output
      run.output = output
    end

    def checkpoint_step(step_definition, result)
      run.checkpoint!(step_name: step_definition.name, kind: step_definition.kind, status: :completed, payload: { result: result })
      run.add_event(
        Event.new(
          type: "step.checkpointed",
          step_name: step_definition.name,
          payload: run.checkpoint_for(step_definition.name)
        )
      )
    end

    def checkpoint_output(step_definition)
      key = step_definition.options[:save_as] || step_definition.name
      run.state[key]
    end

    def resume_index
      current_index = self.class.rubot_steps.find_index { |step| step.name == run.current_step } || -1
      current_step = self.class.rubot_steps[current_index]
      return current_index - 1 if current_step&.kind == :approval_step

      current_index
    end

    def final_output
      mapping = self.class.rubot_output_mapping
      return run.public_state unless mapping

      mapping.call(self)
    end

    def resolve_approval_assignment(assigned_to)
      case assigned_to
      when Proc
        instance_exec(run.input, run.state, run.context, &assigned_to)
      else
        assigned_to
      end
    end

    def resolve_relative_time(seconds)
      return if seconds.nil?

      Rubot.configuration.time_source.call + seconds
    end

    def handle_failure(error)
      run.fail!(class: error.class.name, message: error.message)
      run.add_event(Event.new(type: "run.failed", step_name: run.current_step, payload: { error_class: error.class.name, error_message: error.message }))
      handler = self.class.rubot_failure_handler
      return unless handler

      handler.is_a?(Proc) ? instance_exec(error, &handler) : public_send(handler, error)
    end
  end
end
