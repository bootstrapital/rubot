# frozen_string_literal: true

module Rubot
  class RunsController < ApplicationController
    def index
      @runs = rubot_store.all_runs.map { |run| Presenters::RunPresenter.new(run) }
    end

    def show
      run = rubot_store.find_run(params[:id])
      raise ActionController::RoutingError, "Run not found" unless run

      @run = Presenters::RunPresenter.new(run)
    end
  end
end
