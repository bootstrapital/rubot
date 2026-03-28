# frozen_string_literal: true

module Rubot
  module Api
    class RunsController < BaseController
      def show
        run = Rubot.store.load_run(params[:id]) || raise(ActiveRecord::RecordNotFound)
        render json: run.to_h
      end
    end
  end
end
