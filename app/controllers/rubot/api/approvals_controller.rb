# frozen_string_literal: true

module Rubot
  module Api
    class ApprovalsController < BaseController
      def index
        # This is a simplified implementation; real version might filter by role
        runs = Rubot.store.list_runs(status: :waiting_for_approval)
        render json: { approvals: runs.map(&:pending_approval).compact.map(&:to_h) }
      end

      def approve
        run = find_run_by_approval_id
        run.approve!(params[:payload] || {})
        Rubot.resume_later(run)
        render json: { status: "approved", run_id: run.id }
      end

      def reject
        run = find_run_by_approval_id
        run.reject!(params[:payload] || {})
        render json: { status: "rejected", run_id: run.id }
      end

      private

      def find_run_by_approval_id
        # In a real app, you might need a mapping table or search by approval_id
        # For now, we assume params[:id] is the run_id for simplicity or finding via store
        Rubot.store.load_run(params[:id]) || raise(ActiveRecord::RecordNotFound)
      end
    end
  end
end
