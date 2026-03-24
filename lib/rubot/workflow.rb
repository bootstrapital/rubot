# frozen_string_literal: true

module Rubot
  class Workflow
    extend DSL

    class << self
      def step(name, **options, &block)
        rubot_steps << StepDefinition.new(kind: :step, name:, options:, block:)
      end

      def tool_step(name, tool:, input: nil, save_as: nil, **options)
        rubot_steps << StepDefinition.new(kind: :tool_step, name:, options: options.merge(tool:, input:, save_as:))
      end

      def agent_step(name, agent:, input: nil, save_as: nil, **options)
        rubot_steps << StepDefinition.new(kind: :agent_step, name:, options: options.merge(agent:, input:, save_as:))
      end

      def approval_step(name, role: nil, reason: nil, assigned_to: nil, sla_seconds: nil, expires_in: nil, **options)
        rubot_steps << StepDefinition.new(
          kind: :approval_step,
          name:,
          options: options.merge(role:, reason:, assigned_to:, sla_seconds:, expires_in:)
        )
      end

      def branch(name, **options, &block)
        rubot_steps << StepDefinition.new(kind: :branch, name:, options:, block:)
      end

      def on_failure(handler = nil, &block)
        @rubot_failure_handler = handler || block
      end

      def rubot_failure_handler
        @rubot_failure_handler
      end
    end

    def initialize(run:)
      @run = run
    end

    attr_reader :run

    def execute
      self.class.rubot_steps.each do |step_definition|
        run.current_step = step_definition.name
        run.add_event(Event.new(type: "step.entered", step_name: step_definition.name))
        result = execute_step(step_definition)
        run.add_event(Event.new(type: "step.exited", step_name: step_definition.name, payload: { result: result })) unless run.waiting_for_approval?
        return run if run.waiting_for_approval? || run.failed?
      end

      run.complete!(run.state)
    rescue StandardError => e
      handle_failure(e)
      raise
    end

    def resume
      start_index = resume_index
      remaining_steps = self.class.rubot_steps[(start_index + 1)..] || []

      remaining_steps.each do |step_definition|
        run.current_step = step_definition.name
        run.add_event(Event.new(type: "step.entered", step_name: step_definition.name))
        result = execute_step(step_definition)
        run.add_event(Event.new(type: "step.exited", step_name: step_definition.name, payload: { result: result })) unless run.waiting_for_approval?
        return run if run.waiting_for_approval? || run.failed?
      end

      run.complete!(run.state)
    rescue StandardError => e
      handle_failure(e)
      raise
    end

    private

    def execute_step(step_definition)
      case step_definition.kind
      when :step
        step_definition.block ? instance_exec(&step_definition.block) : public_send(step_definition.name)
      when :tool_step
        execute_tool_step(step_definition)
      when :agent_step
        execute_agent_step(step_definition)
      when :approval_step
        execute_approval_step(step_definition)
      when :branch
        instance_exec(run.state, &step_definition.block)
      else
        raise ExecutionError, "Unsupported step kind #{step_definition.kind}"
      end
    end

    def execute_tool_step(step_definition)
      tool_class = step_definition.options.fetch(:tool)
      input = resolve_input(step_definition.options[:input])
      output = tool_class.new.execute(input:, run:)
      persist_step_output(step_definition, output)
      output
    end

    def execute_agent_step(step_definition)
      agent_class = step_definition.options.fetch(:agent)
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
      run.add_event(Event.new(type: "approval.requested", step_name: step_definition.name, payload: approval.to_h))
      nil
    end

    def resolve_input(input)
      case input
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

    def resume_index
      current_index = self.class.rubot_steps.find_index { |step| step.name == run.current_step } || -1
      current_step = self.class.rubot_steps[current_index]
      return current_index - 1 if current_step&.kind == :approval_step

      current_index
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
