# frozen_string_literal: true

module Rubot
  module Api
    class OperationsController < BaseController
      def index
        render json: { operations: Rubot::Engine.operations.keys }
      end

      def show
        operation = find_operation
        render json: operation.discover
      end

      def launch
        operation = find_operation
        run = operation.launch(
          payload: params[:payload] || {},
          subject: params[:subject],
          context: params[:context] || {},
          trigger: params[:trigger],
          workflow: params[:workflow],
          entrypoint: params[:entrypoint]
        )
        render json: run.to_h, status: :accepted
      end

      private

      def find_operation
        Rubot::Engine.operations[params[:id].to_sym] || raise(ActiveRecord::RecordNotFound)
      end
    end
  end
end
