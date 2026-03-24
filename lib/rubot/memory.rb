# frozen_string_literal: true

module Rubot
  module Memory
    class SubjectAdapter
      def fetch(subject:, run:, agent_class:, input:, context:)
        []
      end
    end

    class Config
      attr_reader :processors

      def initialize(processors: [])
        @processors = processors
      end

      def processor(processor_class, **options)
        processors << { processor: processor_class, options: options }
      end

      def dup
        self.class.new(processors: processors.map(&:dup))
      end

      def empty?
        processors.empty?
      end
    end

    class ContextBuilder
      def initialize(config)
        @config = config || Config.new
      end

      def build(messages:, run:, agent_class:, turn:, input:, context:)
        working_messages = deep_copy(messages)
        applied_processors = []

        @config.processors.each do |entry|
          processor = entry.fetch(:processor).new(**entry.fetch(:options))
          before_count = message_count(working_messages)
          before_tokens = token_estimate(working_messages)
          working_messages = processor.call(
            messages: working_messages,
            run: run,
            agent_class: agent_class,
            turn: turn,
            input: input,
            context: context
          )
          applied_processors << {
            processor: processor.class.name,
            before_messages: before_count,
            after_messages: message_count(working_messages),
            before_tokens: before_tokens,
            after_tokens: token_estimate(working_messages)
          }
        end

        {
          messages: working_messages,
          applied_processors: applied_processors,
          estimated_tokens: token_estimate(working_messages)
        }
      end

      private

      def token_estimate(messages)
        Processors::TokenEstimator.estimate(messages)
      end

      def message_count(messages)
        Array(messages).length
      end

      def deep_copy(value)
        case value
        when Array
          value.map { |item| deep_copy(item) }
        when Hash
          value.each_with_object({}) do |(key, nested_value), memo|
            memo[key] = deep_copy(nested_value)
          end
        else
          value
        end
      end
    end

    class SubjectContext
      class << self
        def fetch_messages(subject:, run:, agent_class:, input:, context:)
          adapter = Rubot.configuration.subject_memory_adapter
          return [] unless adapter && subject

          Array(
            adapter.fetch(
              subject: subject,
              run: run,
              agent_class: agent_class,
              input: input,
              context: context
            )
          )
        end
      end
    end

    module Processors
      class TokenEstimator
        class << self
          def estimate(messages)
            Array(messages).sum { |message| estimate_value(message) }
          end

          private

          def estimate_value(value)
            case value
            when Array
              value.sum { |item| estimate_value(item) }
            when Hash
              value.sum { |key, nested_value| estimate_value(key.to_s) + estimate_value(nested_value) }
            when String
              [(value.length / 4.0).ceil, 1].max
            when NilClass
              0
            else
              estimate_value(value.to_s)
            end
          end
        end
      end

      class TokenLimiter
        def initialize(max_tokens:)
          @max_tokens = max_tokens
        end

        def call(messages:, **)
          working_messages = Array(messages).map(&:dup)
          system_messages, remaining_messages = working_messages.partition { |message| message[:role].to_s == "system" }

          while TokenEstimator.estimate(system_messages + remaining_messages) > @max_tokens && remaining_messages.any?
            remaining_messages.shift
          end

          system_messages + remaining_messages
        end
      end

      class ToolCallFilter
        def call(messages:, **)
          Array(messages).filter_map do |message|
            role = message[:role].to_s
            next if role == "tool"

            normalized = message.dup
            normalized.delete(:tool_calls)
            next if role == "assistant" && blank_content?(normalized[:content])

            normalized
          end
        end

        private

        def blank_content?(value)
          value.nil? || value.to_s.strip.empty?
        end
      end
    end
  end
end
