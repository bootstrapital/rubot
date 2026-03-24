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

      def failed?
        run.failed?
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
