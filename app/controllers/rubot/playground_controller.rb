# frozen_string_literal: true

module Rubot
  class PlaygroundController < ApplicationController
    before_action :load_playground_state

    def index; end

    def create
      @input_json = params[:input_json].to_s
      @context_json = params[:context_json].to_s
      @subject_json = params[:subject_json].to_s

      run = Rubot::Playground::Invocation.new.call(
        kind: @kind,
        runnable: @runnable,
        input: parse_json(@input_json, empty: {}),
        context: parse_json(@context_json, empty: {}),
        subject: parse_json(@subject_json, empty: nil)
      )

      @result = Presenters::RunPresenter.new(run)
      render :index
    rescue JSON::ParserError => e
      @error_message = "Invalid JSON: #{e.message}"
      render :index, status: :unprocessable_entity
    rescue StandardError => e
      @error_message = e.message
      render :index, status: :unprocessable_entity
    end

    private

    def load_playground_state
      registry = Rubot::Playground::Registry.new
      @kind = normalize_kind(params[:kind])
      @available = registry.classes(@kind)
      @class_name = params[:class_name].presence || @available.first&.name
      @runnable = @class_name && registry.resolve(@kind, @class_name)
      @fixtures = @runnable ? Rubot::Playground::FixtureSet.new(@runnable).options : []
      selected_fixture = @fixtures.find { |fixture| fixture[:name].to_s == params[:fixture].to_s } || @fixtures.first
      @input_json ||= rubot_json(selected_fixture&.fetch(:input, {}))
      @context_json ||= rubot_json(selected_fixture&.fetch(:context, {}))
      @subject_json ||= rubot_json(selected_fixture&.fetch(:subject, nil))
    end

    def parse_json(value, empty:)
      return empty if value.blank?
      return nil if value.strip == "null"

      JSON.parse(value, symbolize_names: true)
    end

    def normalize_kind(value)
      normalized = value.to_s.presence || "workflow"
      return normalized.to_sym if %w[tool agent workflow].include?(normalized)

      :workflow
    end
  end
end
