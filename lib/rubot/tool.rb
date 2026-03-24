# frozen_string_literal: true

module Rubot
  class Tool
    extend DSL

    class << self
      attr_reader :rubot_timeout, :rubot_retry_policy, :rubot_idempotent

      def idempotent!
        @rubot_idempotent = true
      end

      def timeout(seconds)
        @rubot_timeout = seconds
      end

      def retry_on(*errors, attempts: 3)
        @rubot_retry_policy = { errors:, attempts: }
      end

      def call(**input)
        new.call(**input)
      end
    end

    def call(**_input)
      raise NotImplementedError, "#{self.class.name} must implement #call"
    end

    def execute(input:, run:)
      started_at = Rubot.configuration.time_source.call
      validated_input = self.class.input_schema.validate!(input)

      run.add_event(Event.new(type: "tool.invoked", step_name: run.current_step, payload: { tool_name: self.class.name, input: validated_input }))
      output = call(**validated_input)
      self.class.output_schema.validate!(output) unless self.class.output_schema.fields.empty?

      duration_ms = ((Rubot.configuration.time_source.call - started_at) * 1000).round
      call_record = {
        tool_name: self.class.name,
        status: "completed",
        input: validated_input,
        output: output,
        duration_ms: duration_ms
      }
      run.add_tool_call(call_record)
      run.add_event(Event.new(type: "tool.completed", step_name: run.current_step, payload: call_record))
      output
    rescue StandardError => e
      duration_ms = ((Rubot.configuration.time_source.call - started_at) * 1000).round
      call_record = {
        tool_name: self.class.name,
        status: "failed",
        input: input,
        error: { class: e.class.name, message: e.message },
        duration_ms: duration_ms
      }
      run.add_tool_call(call_record)
      run.add_event(Event.new(type: "tool.failed", step_name: run.current_step, payload: call_record))
      raise
    end
  end
end
