# frozen_string_literal: true

begin
  require "active_job"
rescue LoadError
  nil
end

module Rubot
  class Async
    class << self
      def enqueue(workflow_or_agent, input:, subject: nil, context: {}, trace_id: nil, replay_of_run_id: nil)
        ensure_active_job!

        run = Executor.new.send(:build_run, workflow_or_agent, input:, subject:, context:, trace_id:, replay_of_run_id:)
        Rubot::RunJob.perform_later(run.id)
        run
      end

      def resume_later(run_or_id)
        ensure_active_job!

        run_id = run_or_id.respond_to?(:id) ? run_or_id.id : run_or_id
        run = run_or_id.is_a?(Rubot::Run) ? run_or_id : Rubot.store.find_run(run_id)
        return run if run&.cancel_requested? || run&.canceled?

        Rubot::ResumeRunJob.perform_later(run_id)
      end

      private

      def ensure_active_job!
        raise ExecutionError, "Active Job is not available" unless defined?(ActiveJob::Base)
      end
    end
  end
end
