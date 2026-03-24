# frozen_string_literal: true

module Rubot
  class DashboardController < ApplicationController
    def index
      runs = rubot_store.all_runs
      summary = Rubot::Metrics::Aggregator.new(runs).summary
      @dashboard = {
        summary: summary,
        recent_runs: runs.first(5).map { |run| Presenters::RunPresenter.new(run) }
      }

      respond_to do |format|
        format.html
        format.json { render json: { dashboard: { summary:, recent_runs: @dashboard[:recent_runs].map(&:as_admin_json) } } }
      end
    end
  end
end
