# frozen_string_literal: true

module Rubot
  module Presenters
    class RunPresenter
      def initialize(run)
        @run = run
      end

      attr_reader :run

      def id
        run.id
      end

      def name
        run.name
      end

      def status
        run.status.to_s.tr("_", " ")
      end

      def current_step
        run.current_step&.to_s || "not started"
      end

      def started_at
        run.started_at&.iso8601 || "not started"
      end

      def completed_at
        run.completed_at&.iso8601 || "in progress"
      end

      def duration
        return "n/a" unless run.started_at

        end_time = run.completed_at || Rubot.configuration.time_source.call
        seconds = (end_time - run.started_at).round(1)
        "#{seconds}s"
      end

      def events
        run.events
      end

      def approvals
        run.approvals
      end

      def tool_calls
        @tool_calls ||= run.tool_calls.each_with_index.map do |tool_call, index|
          ToolCallPresenter.new(run, tool_call, index:)
        end
      end

      def output
        run.output
      end

      def trace_id
        run.trace_id
      end

      def replay_of_run_id
        run.replay_of_run_id
      end

      def as_admin_json
        {
          id: id,
          name: name,
          kind: run.kind,
          trace_id: trace_id,
          replay_of_run_id: replay_of_run_id,
          status: run.status,
          current_step: run.current_step,
          started_at: run.started_at&.iso8601,
          completed_at: run.completed_at&.iso8601,
          duration: duration,
          subject: subject_label,
          confidence: confidence,
          warnings: warnings,
          approvals: run.approvals.map(&:to_h),
          tool_calls: tool_calls.map(&:as_admin_json),
          metrics: metrics,
          output: output,
          error: error,
          steps: step_groups.map do |step|
            {
              name: step[:name],
              status: step[:status],
              confidence: step[:confidence],
              warnings: step[:warnings],
              event_count: step[:events].length,
              tool_call_ids: step[:tool_calls].map(&:id),
              result: step[:result]
            }
          end,
          events: run.events.map(&:to_h)
        }
      end

      def failed?
        run.failed?
      end

      def metrics
        {
          duration_seconds: duration_seconds,
          approval_wait_seconds: approval_wait_seconds,
          tool_calls_total: run.tool_calls.length,
          tool_calls_failed: run.tool_calls.count { |tool_call| tool_call[:status] == "failed" || tool_call["status"] == "failed" },
          model_tokens: model_usage[:total_tokens],
          model_cost: model_usage[:total_cost]
        }
      end

      def error
        run.error
      end

      def subject_label
        return unless run.subject

        if run.subject.respond_to?(:id)
          "#{run.subject.class.name}##{run.subject.id}"
        else
          run.subject.to_s
        end
      end

      def warnings
        extract_warnings(output)
      end

      def confidence
        extract_confidence(output)
      end

      def step_groups
        @step_groups ||= begin
          grouped_events = run.events.group_by { |event| event.step_name&.to_s }
          step_names = run.events.filter_map { |event| event.step_name&.to_s }.uniq
          step_names.map do |step_name|
            state_key = run.state.key?(step_name.to_sym) ? step_name.to_sym : step_name
            {
              name: step_name,
              status: step_status(step_name),
              result: run.state[state_key],
              warnings: extract_warnings(run.state[state_key]),
              confidence: extract_confidence(run.state[state_key]),
              events: grouped_events.fetch(step_name, []),
              tool_calls: tool_calls.select { |tool_call| tool_call.step_name == step_name }
            }
          end
        end
      end

      private

      def duration_seconds
        return unless run.started_at

        end_time = run.completed_at || Rubot.configuration.time_source.call
        (end_time - run.started_at).round(2)
      end

      def approval_wait_seconds
        waits = run.approvals.filter_map do |approval|
          request_event = run.events.find do |event|
            event.type == "approval.requested" && event.step_name.to_s == approval.step_name.to_s
          end
          next unless request_event

          ((approval.decided_at || Rubot.configuration.time_source.call) - request_event.timestamp).round(2)
        end
        return if waits.empty?

        (waits.sum / waits.length.to_f).round(2)
      end

      def model_usage
        @model_usage ||= begin
          usage_rows = run.events.filter_map do |event|
            next unless event.type == "model.response.received"

            event.payload[:usage] || event.payload["usage"]
          end

          {
            total_tokens: usage_rows.sum { |usage| usage[:total_tokens] || usage["total_tokens"] || 0 },
            total_cost: usage_rows.sum { |usage| usage[:total_cost] || usage["total_cost"] || 0.0 }.round(6)
          }
        end
      end

      def step_status(step_name)
        return :failed if failed? && run.current_step.to_s == step_name
        return :waiting_for_approval if run.waiting_for_approval? && run.current_step.to_s == step_name
        return :running if run.running? && run.current_step.to_s == step_name
        return :completed if run.state.key?(step_name.to_sym)

        :entered
      end

      def extract_warnings(value)
        return [] unless value.is_a?(Hash)

        Array(value[:warnings] || value["warnings"]).map(&:to_s)
      end

      def extract_confidence(value)
        return unless value.is_a?(Hash)

        value[:confidence] || value["confidence"]
      end
    end
  end
end
