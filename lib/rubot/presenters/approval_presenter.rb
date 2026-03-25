# frozen_string_literal: true

module Rubot
  module Presenters
    class ApprovalPresenter
      def initialize(run, approval)
        @run = run
        @approval = approval
      end

      attr_reader :run, :approval

      def run_id
        run.id
      end

      def run_name
        run.name
      end

      def step_name
        approval.step_name
      end

      def role_requirement
        approval.role_requirement || "unscoped"
      end

      def role
        approval.role || "unscoped"
      end

      def reason
        approval.reason || "No reason supplied."
      end

      def status
        approval.status.to_s
      end

      def as_admin_json
        {
          run_id: run_id,
          run_name: run_name,
          step_name: step_name,
          role: role,
          role_requirement: role_requirement,
          reason: reason,
          status: status,
          assigned_to: approval.assigned_to,
          assigned_to_type: approval.assigned_to_type,
          assigned_to_id: approval.assigned_to_id,
          sla_due_at: approval.sla_due_at&.iso8601,
          expires_at: approval.expires_at&.iso8601
        }
      end
    end
  end
end
