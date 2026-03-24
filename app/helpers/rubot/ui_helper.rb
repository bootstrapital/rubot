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
      Rubot.store.find_runs_for_subject(subject)
           .first(limit)
           .compact
           .map { |run| Presenters::RunPresenter.new(run) }
    end

    def rubot_subject_runs_widget(subject, limit: 5)
      render("rubot/runs/subject_widget", subject:, runs: rubot_runs_for(subject, limit:))
    end

    def rubot_nav_link(item, current_path:)
      active = current_path == item[:path]
      classes = ["rubot-shell__nav-link"]
      classes << "rubot-shell__nav-link--active" if active
      link_to item[:label], item[:path], class: classes.join(" ")
    end

    def rubot_cell_value(row, column)
      value = column[:value]
      return value.call(row) if value.respond_to?(:call)

      key = column[:key]
      return row.public_send(key) if key && row.respond_to?(key)
      return row[key] if key && row.is_a?(Hash)

      nil
    end

    def rubot_schema_fields(schema)
      return [] unless schema.respond_to?(:fields)

      schema.fields.map do |field|
        {
          name: field.name,
          label: field.name.to_s.tr("_", " ").capitalize,
          type: field.type,
          required: field.required,
          item_type: field.item_type
        }
      end
    end

    def rubot_schema_value_pairs(payload, schema = nil)
      payload = payload || {}

      if schema.respond_to?(:fields)
        rubot_schema_fields(schema).map do |field|
          { label: field[:label], value: payload[field[:name]] || payload[field[:name].to_s] }
        end
      else
        payload.map do |key, value|
          { label: key.to_s.tr("_", " ").capitalize, value: value }
        end
      end
    end

    def rubot_schema_input_type(field)
      case field[:type]
      when :integer, :float
        :number_field
      when :boolean
        :check_box
      else
        :text_field
      end
    end

    def rubot_diff_rows(before_value, after_value)
      before_hash = before_value.is_a?(Hash) ? before_value : {}
      after_hash = after_value.is_a?(Hash) ? after_value : {}
      keys = (before_hash.keys + after_hash.keys).map(&:to_s).uniq.sort

      keys.map do |key|
        before_item = before_hash[key.to_sym] || before_hash[key]
        after_item = after_hash[key.to_sym] || after_hash[key]
        status =
          if before_item.nil? && !after_item.nil?
            :added
          elsif !before_item.nil? && after_item.nil?
            :removed
          elsif before_item == after_item
            :unchanged
          else
            :changed
          end

        { key:, before: before_item, after: after_item, status: }
      end
    end

    def rubot_json(value)
      JSON.pretty_generate(value || {})
    end
  end
end
