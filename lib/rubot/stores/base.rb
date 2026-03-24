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
    end
  end
end
