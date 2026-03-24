# frozen_string_literal: true

module Rubot
  module UiHelper
    def rubot_live_updates_enabled?
      defined?(Turbo::StreamsHelper) && Rubot::LiveUpdates.enabled?
    end

    def rubot_status_badge(status)
      content_tag(:span, status.to_s.tr("_", " "), class: "rubot-badge rubot-badge--#{status.to_s.dasherize}")
    end

    def rubot_confidence_badge(value)
      return unless value

      percentage = (value.to_f * 100).round
      modifier =
        if value.to_f >= 0.8
          "high"
        elsif value.to_f >= 0.5
          "medium"
        else
          "low"
        end

      content_tag(:span, "confidence #{percentage}%", class: "rubot-badge rubot-badge--confidence-#{modifier}")
    end

    def rubot_warning_badges(warnings)
      Array(warnings).filter_map do |warning|
        next if warning.to_s.strip.empty?

        content_tag(:span, warning, class: "rubot-badge rubot-badge--warning")
      end.join.html_safe
    end

    def rubot_runs_for(subject, limit: 5)
      runs =
        if defined?(Rubot::RunRecord) && Rubot.store.is_a?(Rubot::Stores::ActiveRecordStore) && subject.respond_to?(:id)
          Rubot::RunRecord.includes(:event_records, :tool_call_records, :approval_records)
                           .where(subject_type: subject.class.name, subject_id: subject.id.to_s)
                           .order(started_at: :desc, created_at: :desc)
                           .limit(limit)
                           .map { |record| Rubot.store.find_run(record.id) }
        else
          Rubot.store.all_runs.select do |run|
            run.subject == subject ||
              (subject.respond_to?(:id) && run.subject&.respond_to?(:id) &&
                run.subject.class.name == subject.class.name && run.subject.id.to_s == subject.id.to_s)
          end.first(limit)
        end

      runs.compact.map { |run| Presenters::RunPresenter.new(run) }
    end

    def rubot_subject_runs_widget(subject, limit: 5)
      render("rubot/runs/subject_widget", subject:, runs: rubot_runs_for(subject, limit:))
    end

    def rubot_json(value)
      JSON.pretty_generate(value || {})
    end
  end
end
