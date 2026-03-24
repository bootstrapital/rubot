# frozen_string_literal: true

module Rubot
  module Metrics
    class Aggregator
      def initialize(runs)
        @runs = Array(runs)
      end

      def summary
        {
          total_runs: @runs.length,
          active_runs: @runs.count { |run| %i[queued running waiting_for_approval].include?(run.status) },
          pending_approvals: @runs.sum { |run| run.approvals.count(&:pending?) },
          failed_runs: @runs.count(&:failed?),
          average_duration_seconds: average_duration_seconds,
          tool_success_rate: tool_success_rate,
          total_model_tokens: total_model_tokens,
          total_model_cost: total_model_cost,
          average_approval_wait_seconds: average_approval_wait_seconds
        }
      end

      private

      def average_duration_seconds
        durations = @runs.filter_map do |run|
          next unless run.started_at

          end_time = run.completed_at || Rubot.configuration.time_source.call
          end_time - run.started_at
        end
        average(durations)
      end

      def tool_success_rate
        tool_calls = @runs.flat_map(&:tool_calls)
        return nil if tool_calls.empty?

        completed = tool_calls.count { |tool_call| (tool_call[:status] || tool_call["status"]) == "completed" }
        completed.to_f / tool_calls.length
      end

      def total_model_tokens
        @runs.sum do |run|
          run.events.sum do |event|
            next 0 unless event.type == "model.response.received"

            usage = event.payload[:usage] || event.payload["usage"] || {}
            usage[:total_tokens] || usage["total_tokens"] || 0
          end
        end
      end

      def total_model_cost
        @runs.sum do |run|
          run.events.sum do |event|
            next 0.0 unless event.type == "model.response.received"

            usage = event.payload[:usage] || event.payload["usage"] || {}
            usage[:total_cost] || usage["total_cost"] || 0.0
          end
        end.round(6)
      end

      def average_approval_wait_seconds
        waits = @runs.flat_map do |run|
          run.approvals.filter_map do |approval|
            wait_seconds(run, approval)
          end
        end
        average(waits)
      end

      def wait_seconds(run, approval)
        request_event = run.events.find do |event|
          event.type == "approval.requested" && event.step_name.to_s == approval.step_name.to_s
        end
        return unless request_event

        decided_at = approval.decided_at || Rubot.configuration.time_source.call
        decided_at - request_event.timestamp
      end

      def average(values)
        return nil if values.empty?

        (values.sum.to_f / values.length).round(2)
      end
    end
  end
end
