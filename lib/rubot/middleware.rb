# frozen_string_literal: true

module Rubot
  module Middleware
    # Public extension API for agent/provider middleware entries.
    class Base
      attr_reader :app, :options

      def initialize(app, **options)
        @app = app
        @options = options
      end

      def call(env)
        app.call(env)
      end
    end

    # Public convenience base for authorization-oriented middleware.
    class Authorization < Base
      def call(env)
        authorize!(env)
        app.call(env)
      end

      def authorize!(_env)
        true
      end
    end

    # Public convenience base for input/message guardrail middleware.
    class Guardrail < Base
      def call(env)
        guarded_env = env.dup
        guarded_env[:input] = guard_input(guarded_env[:input], guarded_env) if guarded_env.key?(:input)
        guarded_env[:messages] = guard_messages(guarded_env[:messages], guarded_env) if guarded_env.key?(:messages)
        app.call(guarded_env)
      end

      def guard_input(input, _env)
        input
      end

      def guard_messages(messages, _env)
        messages
      end
    end

    # Internal: runtime middleware composer.
    class Stack
      def initialize(entries, terminal)
        @app = entries.reverse.inject(terminal) do |app, entry|
          build(entry, app)
        end
      end

      def call(env)
        @app.call(env)
      end

      private

      def build(entry, app)
        middleware_class = entry.fetch(:middleware)
        options = entry.fetch(:options)
        middleware_class.new(app, **options)
      end
    end
  end
end
