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

      def reason
        approval.reason || "No reason supplied."
      end

      def status
        approval.status.to_s
      end
    end
  end
end
