# frozen_string_literal: true

module Rubot
  class RunsController < ApplicationController
    def index
      authorize_rubot_action!(:view, resource: Rubot::Run)
      @runs = rubot_store.all_runs.map { |run| Presenters::RunPresenter.new(run) }
      respond_to do |format|
        format.html
        format.json { render json: { runs: @runs.map(&:as_admin_json) } }
      end
    end

    def show
      run = rubot_store.find_run(params[:id])
      raise ActionController::RoutingError, "Run not found" unless run

      authorize_rubot_action!(:view, run:)
      @run = Presenters::RunPresenter.new(run)
      @comparison_run = build_comparison_run
      respond_to do |format|
        format.html
        format.json { render json: { run: @run.as_admin_json } }
      end
    end

    def replay
      source = rubot_store.find_run(params[:id])
      raise ActionController::RoutingError, "Run not found" unless source

      authorize_rubot_action!(:start, run: source)
      replayed = Rubot.replay(source)
      redirect_to rubot.run_path(replayed.id, compare_to: source.id)
    end

    private

    def build_comparison_run
      comparison_id = params[:compare_to].presence || @run.replay_of_run_id
      return unless comparison_id

      comparison_run = rubot_store.find_run(comparison_id)
      comparison_run && Presenters::RunPresenter.new(comparison_run)
    end
  end
end
