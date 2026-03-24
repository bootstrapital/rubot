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

      messages = provider_messages(input:, context:)
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

        provider_result = invoke_provider_middleware(
          input: input,
          context: context,
          run: run,
          turn: turn,
          messages: messages
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
          messages << {
            role: :assistant,
            content: provider_result.content,
            tool_calls: provider_result.tool_calls
          }.compact
          messages.concat(execute_provider_tool_calls(provider_result.tool_calls, run))
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

    def provider_messages(input:, context:)
      messages = []
      instructions = self.class.instructions
      messages << { role: :system, content: instructions } if instructions
      messages << { role: :user, content: JSON.generate(input: input, context: context) }
      messages
    end

    def normalize_provider_output(result)
      return symbolize_hash(result.output) if result.output

      parsed = parse_json_content(result.content)
      return parsed if parsed

      raise Rubot::ValidationError, "#{self.class.name} provider response did not include structured output"
    end

    def execute_provider_tool_calls(tool_calls, run)
      registry = tool_registry

      Array(tool_calls).map do |tool_call|
        normalized_call = symbolize_hash(tool_call)
        tool_name = normalized_call[:name] || normalized_call[:tool_name] || normalized_call.dig(:function, :name)
        tool_class = registry[tool_name]
        raise Rubot::ExecutionError, "#{self.class.name} requested unknown tool #{tool_name}" unless tool_class

        raw_arguments = normalized_call[:arguments] || normalized_call.dig(:function, :arguments) || {}
        arguments = raw_arguments.is_a?(String) ? parse_json_content(raw_arguments) : symbolize_hash(raw_arguments)
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

    def tool_registry
      self.class.rubot_tools.each_with_object({}) do |tool_class, memo|
        memo[tool_class.name] = tool_class
        memo[tool_class.name.split("::").last] = tool_class
      end
    end

    def invoke_provider_middleware(input:, context:, run:, turn:, messages:)
      env = {
        phase: :provider,
        agent_class: self.class,
        input: input,
        context: context,
        run: run,
        turn: turn,
        messages: messages,
        tools: self.class.rubot_tools,
        output_schema: self.class.output_schema,
        model: self.class.model
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

      symbolize_hash(JSON.parse(content))
    rescue JSON::ParserError
      nil
    end

    def symbolize_hash(value)
      case value
      when Array
        value.map { |item| symbolize_hash(item) }
      when Hash
        value.each_with_object({}) do |(key, nested_value), memo|
          memo[key.respond_to?(:to_sym) ? key.to_sym : key] = symbolize_hash(nested_value)
        end
      else
        value
      end
    end
  end
end
