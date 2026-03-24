# frozen_string_literal: true

module Rubot
  class ToolCallsController < ApplicationController
    def show
      run = rubot_store.find_run(params[:run_id])
      raise ActionController::RoutingError, "Run not found" unless run

      @run = Presenters::RunPresenter.new(run)
      @tool_call = @run.tool_calls[params[:id].to_i]
      raise ActionController::RoutingError, "Tool call not found" unless @tool_call
    end
  end
end
