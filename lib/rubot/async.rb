# frozen_string_literal: true

begin
  require "active_job"
rescue LoadError
  nil
end

module Rubot
  class Async
    class << self
      def enqueue(workflow_or_agent, input:, subject: nil, context: {})
        ensure_active_job!

        run = Executor.new.send(:build_run, workflow_or_agent, input:, subject:, context:)
        Rubot::RunJob.perform_later(run.id)
        run
      end

      def resume_later(run_or_id)
        ensure_active_job!

        run_id = run_or_id.respond_to?(:id) ? run_or_id.id : run_or_id
        Rubot::ResumeRunJob.perform_later(run_id)
      end

      private

      def ensure_active_job!
        raise ExecutionError, "Active Job is not available" unless defined?(ActiveJob::Base)
      end
    end
  end
end
