# frozen_string_literal: true

begin
  require "ruby_llm"
rescue LoadError
  nil
end

module Rubot
  module Providers
    class RubyLLM < Base
      attr_reader :transport

      def initialize(transport: nil, model: nil, provider_name: nil)
        @transport = transport || DefaultTransport.new
        @model = model
        @provider_name = provider_name
      end

      def complete(messages:, tools: [], output_schema: nil, model: nil, provider: nil, **options)
        request = {
          model: model || @model || Rubot.configuration.default_model,
          provider: provider || @provider_name || Rubot.configuration.default_provider_name,
          messages: normalize_messages(messages),
          tools: normalize_tools(tools),
          output_schema: output_schema,
          normalized_output_schema: normalize_output_schema(output_schema),
          options: options
        }

        response = transport.complete(request)
        normalize_result(response, request: request)
      end

      private

      def normalize_messages(messages)
        Array(messages).map do |message|
          normalized = symbolize_hash(message)
          {
            role: normalized.fetch(:role).to_s,
            content: normalized[:content],
            name: normalized[:name],
            tool_call_id: normalized[:tool_call_id],
            tool_calls: normalize_tool_calls(normalized[:tool_calls])
          }.compact
        end
      end

      def normalize_tools(tools)
        Array(tools).map do |tool_class|
          {
            name: tool_class.name,
            description: tool_class.respond_to?(:description) ? tool_class.description : nil,
            input_schema: tool_class.input_schema.to_json_schema,
            output_schema: tool_class.output_schema.to_json_schema
          }.compact
        end
      end

      def normalize_output_schema(output_schema)
        return unless output_schema

        output_schema.to_json_schema
      end

      def normalize_result(response, request:)
        normalized = response.respond_to?(:to_h) ? symbolize_hash(response.to_h) : symbolize_hash(response)
        tool_calls = normalize_tool_calls(normalized[:tool_calls])
        output = normalize_output_payload(normalized, request:, tool_calls:)

        Result.new(
          content: normalized[:content] || normalized[:text],
          output: output,
          tool_calls: tool_calls,
          usage: normalize_usage(normalized[:usage]),
          finish_reason: normalized[:finish_reason],
          model: normalized[:model] || request[:model],
          provider: normalized[:provider] || request[:provider] || self.class.name.split("::").last,
          raw: response
        )
      end

      def parse_json_content(content)
        return unless content.is_a?(String) && !content.strip.empty?

        symbolize_hash(JSON.parse(content))
      rescue JSON::ParserError
        nil
      end

      def normalize_tool_calls(tool_calls)
        Array(tool_calls).map do |tool_call|
          normalized = symbolize_hash(tool_call)
          arguments = normalized[:arguments] || normalized.dig(:function, :arguments)
          normalized[:arguments] = parse_arguments(arguments)
          normalized
        end
      end

      def normalize_usage(usage)
        return unless usage

        usage = symbolize_hash(usage)
        {
          input_tokens: usage[:input_tokens] || usage[:prompt_tokens],
          output_tokens: usage[:output_tokens] || usage[:completion_tokens],
          total_tokens: usage[:total_tokens],
          input_cost: usage[:input_cost] || usage[:prompt_cost],
          output_cost: usage[:output_cost] || usage[:completion_cost],
          total_cost: usage[:total_cost] || usage[:cost],
          currency: usage[:currency]
        }.compact
      end

      def normalize_output_payload(normalized, request:, tool_calls:)
        output = normalized[:output]
        output = parse_json_content(normalized[:content]) if output.nil? && request[:output_schema]
        return output unless request[:output_schema]
        return output if tool_calls.any?

        if output.nil?
          raise Rubot::ValidationError, "Model response did not include structured output matching #{schema_field_names(request[:output_schema])}"
        end

        request[:output_schema].validate!(output)
      rescue Rubot::ValidationError => e
        raise Rubot::ValidationError, "Model response did not satisfy output schema: #{e.message}. Output: #{output.inspect}"
      end

      def schema_field_names(schema)
        schema.fields.map(&:name).join(", ")
      end

      def parse_arguments(arguments)
        case arguments
        when String
          symbolize_hash(JSON.parse(arguments))
        when Hash
          symbolize_hash(arguments)
        else
          arguments
        end
      rescue JSON::ParserError
        arguments
      end

      class DefaultTransport
        def complete(request)
          raise Rubot::ExecutionError, "RubyLLM is not available" unless defined?(::RubyLLM)

          chat = if request[:provider]
            ::RubyLLM.chat(model: request[:model], provider: request[:provider])
          else
            ::RubyLLM.chat(model: request[:model])
          end

          chat = attach_output_schema(chat, request[:normalized_output_schema])
          chat = attach_tools(chat, request[:tools])
          response = deliver(chat, request[:messages], request[:options])
          extract_response(response)
        end

        private

        def attach_output_schema(chat, output_schema)
          return chat unless output_schema
          return chat.with_schema(output_schema) if chat.respond_to?(:with_schema)
          return chat.schema(output_schema) if chat.respond_to?(:schema)

          chat
        end

        def attach_tools(chat, tools)
          Array(tools).each do |tool|
            if chat.respond_to?(:with_tool)
              chat = chat.with_tool(tool)
            elsif chat.respond_to?(:tool)
              chat = chat.tool(tool)
            end
          end
          chat
        end

        def deliver(chat, messages, options)
          if chat.respond_to?(:complete)
            chat.complete(messages:, **options)
          elsif chat.respond_to?(:ask)
            chat.ask(messages, **options)
          else
            raise Rubot::ExecutionError, "RubyLLM chat transport does not support #complete or #ask"
          end
        end

        def extract_response(response)
          response.respond_to?(:to_h) ? response.to_h : response
        end
      end
    end
  end
end
