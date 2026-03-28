# frozen_string_literal: true

module Rubot
  module Api
    class BaseController < ActionController::API
      # API controllers don't use layouts or CSRF by default
      
      rescue_from Rubot::Error, with: :handle_rubot_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

      private

      def handle_rubot_error(error)
        render json: { error: { class: error.class.name, message: error.message } }, status: :unprocessable_entity
      end

      def handle_not_found
        render json: { error: "Resource not found" }, status: :not_found
      end
    end
  end
end
