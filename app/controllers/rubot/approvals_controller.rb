# frozen_string_literal: true

module Rubot
  class ApprovalsController < ApplicationController
    def index
      @approvals = rubot_store.pending_approvals.flat_map do |run|
        run.approvals.select { |approval| approval.status == :pending }.map do |approval|
          Presenters::ApprovalPresenter.new(run, approval)
        end
      end
    end

    def approve
      run = rubot_store.find_run(params[:id])
      raise ActionController::RoutingError, "Run not found" unless run

      run.approve!(approval_payload)
      Rubot::Executor.new.resume(Object.const_get(run.name), run) if workflow_class?(run.name)
      redirect_to rubot.run_path(run.id), notice: "Approval recorded."
    end

    def reject
      run = rubot_store.find_run(params[:id])
      raise ActionController::RoutingError, "Run not found" unless run

      run.reject!(approval_payload)
      redirect_to rubot.run_path(run.id), alert: "Run rejected."
    end

    private

    def approval_payload
      {
        approved_by: params[:approved_by].presence || "operator",
        note: params[:note].to_s
      }
    end

    def workflow_class?(class_name)
      Object.const_defined?(class_name) && Object.const_get(class_name) < Rubot::Workflow
    end
  end
end
