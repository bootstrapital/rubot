# frozen_string_literal: true

module Rubot
  module Presenters
    class ToolCallPresenter
      def initialize(run, tool_call, index:)
        @run = run
        @tool_call = tool_call
        @index = index
      end

      attr_reader :run, :tool_call, :index

      def id
        index
      end

      def run_id
        run.id
      end

      def name
        tool_call[:tool_name] || tool_call["tool_name"]
      end

      def short_name
        name.to_s.split("::").last
      end

      def status
        (tool_call[:status] || tool_call["status"]).to_s
      end

      def step_name
        matched_event&.step_name&.to_s
      end

      def duration_ms
        tool_call[:duration_ms] || tool_call["duration_ms"]
      end

      def input
        tool_call[:input] || tool_call["input"] || {}
      end

      def output
        tool_call[:output] || tool_call["output"]
      end

      def error
        tool_call[:error] || tool_call["error"]
      end

      def warnings
        return [] unless output.is_a?(Hash)

        Array(output[:warnings] || output["warnings"]).map(&:to_s)
      end

      def confidence
        return unless output.is_a?(Hash)

        output[:confidence] || output["confidence"]
      end

      private

      def matched_event
        @matched_event ||= begin
          event_type = status == "failed" ? "tool.failed" : "tool.completed"
          matching_events = run.events.select { |event| event.type == event_type }
          matching_events[index]
        end
      end
    end
  end
end
