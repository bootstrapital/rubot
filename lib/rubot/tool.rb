# frozen_string_literal: true

module Rubot
  # Public API: subclass Rubot::Tool for application actions.
  # Stable subclass hooks are the DSL macros plus #call.
  # Internal runtime methods like #execute are framework-owned.
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

      def retryable_error?(error)
        return false unless rubot_retry_policy

        Array(rubot_retry_policy[:errors]).any? { |klass| error.is_a?(klass) }
      end

      def call(**input)
        new.call(**input)
      end

      def audit_metadata
        {}
      end
    end

    def call(**_input)
      raise NotImplementedError, "#{self.class.name} must implement #call"
    end

    # Internal: Rubot runtime entrypoint used by workflows and agents.
    def execute(input:, run:)
      started_at = Rubot.configuration.time_source.call
      run.raise_if_canceled!
      Rubot::Policy.authorize!(action: :execute_tool, resource: self.class, run: run, context: run.context, fail_run: true)
      validated_input = self.class.input_schema.validate!(input)

      run.add_event(
        Event.new(
          type: "tool.invoked",
          step_name: run.current_step,
          payload: { tool_name: self.class.name, input: validated_input }.merge(self.class.audit_metadata)
        )
      )
      output = call(**validated_input)
      self.class.output_schema.validate!(output) unless self.class.output_schema.fields.empty?

      duration_ms = ((Rubot.configuration.time_source.call - started_at) * 1000).round
      call_record = {
        tool_name: self.class.name,
        status: "completed",
        input: validated_input,
        output: output,
        duration_ms: duration_ms
      }.merge(self.class.audit_metadata)
      run.add_tool_call(call_record)
      run.add_event(Event.new(type: "tool.completed", step_name: run.current_step, payload: call_record))
      run.raise_if_canceled!
      output
    rescue StandardError => e
      e = wrap_retryable_error(e)
      duration_ms = ((Rubot.configuration.time_source.call - started_at) * 1000).round
      call_record = {
        tool_name: self.class.name,
        status: "failed",
        input: input,
        error: { class: e.class.name, message: e.message },
        duration_ms: duration_ms
      }.merge(self.class.audit_metadata)
      run.add_tool_call(call_record)
      run.add_event(Event.new(type: "tool.failed", step_name: run.current_step, payload: call_record))
      raise e
    end

    private

    def wrap_retryable_error(error)
      return error if error.is_a?(Rubot::RetryableError)
      return error unless self.class.retryable_error?(error)

      Rubot::RetryableError.new(
        error.message,
        category: :tool_retryable,
        details: {
          tool_name: self.class.name,
          original_error_class: error.class.name
        }
      )
    end
  end
end
