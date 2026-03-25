# frozen_string_literal: true

module Rubot
  class Agent
    extend DSL

    class << self
      def run(input:, run:, context: {})
        new.run(input:, run:, context:)
      end
    end

    def run(input:, run:, context: {})
      validated_input = self.class.input_schema.validate!(input)
      env = {
        phase: :agent,
        agent_class: self.class,
        input: validated_input,
        run: run,
        context: context
      }

      final_env = invoke_middleware(env) do |middleware_env|
        invoke_hooks(self.class.rubot_before_run_hooks, run, middleware_env[:input], middleware_env[:context])
        result = perform(input: middleware_env[:input], run:, context: middleware_env[:context])
        self.class.output_schema.validate!(result) unless self.class.output_schema.fields.empty?
        invoke_hooks(self.class.rubot_after_run_hooks, run, result, middleware_env[:context])
        run.add_event(Event.new(type: "agent.completed", step_name: run.current_step, payload: { agent_name: self.class.name, output: result }))
        middleware_env.merge(result: result)
      end

      final_env[:result]
    end

    def perform(input:, run:, context:)
      provider = resolve_provider
      raise NotImplementedError, "#{self.class.name} must implement #perform" unless provider

      resolution_context = AgentResolutionContext.new(agent: self, run: run, input: input, context: context)
      resolved_instructions = resolve_runtime_value(self.class.instructions, resolution_context)
      resolved_model = resolve_runtime_value(self.class.model, resolution_context)
      resolved_tools = resolve_tools(resolution_context)

      run.add_event(
        Event.new(
          type: "agent.configuration.resolved",
          step_name: run.current_step,
          payload: {
            agent_name: self.class.name,
            model: resolved_model,
            tools: resolved_tools.map(&:name),
            instructions_preview: resolved_instructions&.to_s&.slice(0, 120)
          }.compact
        )
      )

      conversation_history = provider_messages(input:, context:, instructions: resolved_instructions)
      turn = 0

      loop do
        turn += 1
        raise Rubot::ExecutionError, "#{self.class.name} exceeded #{Rubot.configuration.agent_max_turns} model turns" if turn > Rubot.configuration.agent_max_turns

        run.add_event(
          Event.new(
            type: "agent.tool_loop.iteration",
            step_name: run.current_step,
            payload: { agent_name: self.class.name, turn: turn }
          )
        )

        model_context = build_model_context(
          messages: conversation_history,
          run: run,
          turn: turn,
          input: input,
          context: context
        )

        provider_result = invoke_provider_middleware(
          input: input,
          context: context,
          run: run,
          turn: turn,
          messages: model_context[:messages],
          tools: resolved_tools,
          model: resolved_model
        ) do |middleware_env|
          provider.complete(
            messages: middleware_env[:messages],
            tools: middleware_env[:tools],
            output_schema: middleware_env[:output_schema],
            model: middleware_env[:model]
          )
        end

        run.add_event(
          Event.new(
            type: "model.response.received",
            step_name: run.current_step,
            payload: model_response_payload(provider_result)
          )
        )

        if provider_result.tool_calls.any?
          conversation_history << {
            role: :assistant,
            content: provider_result.content,
            tool_calls: provider_result.tool_calls
          }.compact
          conversation_history.concat(execute_provider_tool_calls(provider_result.tool_calls, run, resolved_tools))
          next
        end

        run.add_event(
          Event.new(
            type: "agent.tool_loop.completed",
            step_name: run.current_step,
            payload: { agent_name: self.class.name, turns: turn }
          )
        )
        return normalize_provider_output(provider_result)
      end
    end

    private

    def resolve_provider
      self.class.provider || Rubot.provider
    end

    def provider_messages(input:, context:, instructions: nil)
      messages = []
      messages << { role: :system, content: instructions } if instructions
      messages << { role: :user, content: JSON.generate(input: input, context: context) }
      messages
    end

    def build_model_context(messages:, run:, turn:, input:, context:)
      subject_messages = Rubot::Memory::SubjectContext.fetch_messages(
        subject: run.subject,
        run: run,
        agent_class: self.class,
        input: input,
        context: context
      )
      working_messages = Array(messages) + Array(subject_messages)

      if subject_messages.any?
        run.add_event(
          Event.new(
            type: "memory.subject_context.loaded",
            step_name: run.current_step,
            payload: {
              agent_name: self.class.name,
              turn: turn,
              subject_type: run.subject_type,
              subject_id: run.subject_id,
              message_count: subject_messages.length
            }.compact
          )
        )
      end

      result = Rubot::Memory::ContextBuilder.new(self.class.rubot_memory_config).build(
        messages: working_messages,
        run: run,
        agent_class: self.class,
        turn: turn,
        input: input,
        context: context
      )

      run.add_event(
        Event.new(
          type: "memory.context.built",
          step_name: run.current_step,
          payload: {
            agent_name: self.class.name,
            turn: turn,
            message_count: result[:messages].length,
            estimated_tokens: result[:estimated_tokens],
            processors: result[:applied_processors]
          }
        )
      )

      result
    end

    def normalize_provider_output(result)
      return Rubot::HashUtils.symbolize(result.output) if result.output

      parsed = parse_json_content(result.content)
      return parsed if parsed

      raise Rubot::ValidationError, "#{self.class.name} provider response did not include structured output"
    end

    def execute_provider_tool_calls(tool_calls, run, tool_classes = self.class.rubot_tools)
      registry = tool_registry(tool_classes)

      Array(tool_calls).map do |tool_call|
        normalized_call = Rubot::HashUtils.symbolize(tool_call)
        tool_name = normalized_call[:name] || normalized_call[:tool_name] || normalized_call.dig(:function, :name)
        tool_class = registry[tool_name]
        raise Rubot::ExecutionError, "#{self.class.name} requested unknown tool #{tool_name}" unless tool_class

        raw_arguments = normalized_call[:arguments] || normalized_call.dig(:function, :arguments) || {}
        arguments = raw_arguments.is_a?(String) ? parse_json_content(raw_arguments) : Rubot::HashUtils.symbolize(raw_arguments)
        raise Rubot::ExecutionError, "#{self.class.name} provided invalid arguments for #{tool_name}" unless arguments.is_a?(Hash)

        output = tool_class.new.execute(input: arguments, run: run)
        {
          role: :tool,
          name: tool_name,
          tool_call_id: normalized_call[:id],
          content: JSON.generate(output)
        }.compact
      end
    end

    def tool_registry(tool_classes = self.class.rubot_tools)
      tool_classes.each_with_object({}) do |tool_class, memo|
        memo[tool_class.name] = tool_class
        memo[tool_class.name.split("::").last] = tool_class
      end
    end

    def invoke_provider_middleware(input:, context:, run:, turn:, messages:, tools:, model:)
      env = {
        phase: :provider,
        agent_class: self.class,
        input: input,
        context: context,
        run: run,
        turn: turn,
        messages: messages,
        tools: tools,
        output_schema: self.class.output_schema,
        model: model
      }

      final_env = invoke_middleware(env) do |middleware_env|
        middleware_env.merge(result: yield(middleware_env))
      end

      final_env[:result]
    end

    def invoke_middleware(env)
      stack = Rubot::Middleware::Stack.new(
        self.class.rubot_middlewares,
        lambda do |middleware_env|
          yield(middleware_env)
        end
      )

      stack.call(env)
    rescue StandardError => e
      env[:run]&.add_event(
        Event.new(
          type: "agent.middleware.halted",
          step_name: env[:run]&.current_step,
          payload: {
            agent_name: self.class.name,
            phase: env[:phase],
            error_class: e.class.name,
            error_message: e.message
          }
        )
      )
      raise
    end

    def model_response_payload(provider_result)
      {
        agent_name: self.class.name,
        provider: provider_result.provider,
        model: provider_result.model,
        finish_reason: provider_result.finish_reason,
        usage: provider_result.usage,
        tool_calls: provider_result.tool_calls
      }.compact
    end

    def resolve_tools(resolution_context)
      value =
        if self.class.rubot_dynamic_tools
          resolve_runtime_value(self.class.rubot_dynamic_tools, resolution_context)
        else
          self.class.rubot_tools
        end

      Array(value)
    end

    def resolve_runtime_value(value, resolution_context)
      case value
      when Proc
        if value.arity == 1
          value.call(resolution_context)
        else
          instance_exec(resolution_context, &value)
        end
      else
        value
      end
    end

    def invoke_hooks(hooks, run, payload, context)
      hooks.each do |hook|
        case hook
        when Proc
          instance_exec(run, payload, context, &hook)
        else
          send(hook, run, payload, context)
        end
      end
    end

    def parse_json_content(content)
      return unless content.is_a?(String) && !content.strip.empty?

      JSON.parse(content, symbolize_names: true)
    rescue JSON::ParserError
      nil
    end
  end
end
