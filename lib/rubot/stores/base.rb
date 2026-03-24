# frozen_string_literal: true

module Rubot
  module Stores
    class Base
      def save_run(_run)
        raise NotImplementedError, "#{self.class.name} must implement #save_run"
      end

      def find_run(_run_id)
        raise NotImplementedError, "#{self.class.name} must implement #find_run"
      end

      def all_runs
        raise NotImplementedError, "#{self.class.name} must implement #all_runs"
      end

      def pending_approvals
        raise NotImplementedError, "#{self.class.name} must implement #pending_approvals"
      end

      def find_runs_for_subject(_subject)
        raise NotImplementedError, "#{self.class.name} must implement #find_runs_for_subject"
      end

      def claim_run_execution(run)
        run
      end

      def release_run_execution(run)
        run
      end

      def execution_claims_supported?
        false
      end
    end
  end
end
