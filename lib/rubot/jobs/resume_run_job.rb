# frozen_string_literal: true

module Rubot
  class ResumeRunJob < BaseJob
    queue_as { Rubot.configuration.resume_job_queue_name }

    def perform(run_id)
      run = load_run!(run_id)
      raise ExecutionError, "ResumeRunJob only supports workflow runs" unless run.kind == :workflow
      return if run.cancel_requested? || run.canceled?

      Rubot::StepJob.perform_later(run.id)
    end
  end if defined?(Rubot::BaseJob)
end
