# frozen_string_literal: true

module Rubot
  module Stores
    class MemoryStore < Base
      def initialize
        @runs = {}
      end

      def save_run(run)
        @runs[run.id] = run
      end

      def find_run(run_id)
        @runs[run_id]
      end

      def all_runs
        @runs.values.sort_by { |run| run.started_at || Time.at(0) }.reverse
      end

      def pending_approvals
        all_runs.select(&:waiting_for_approval?)
      end
    end
  end
end
