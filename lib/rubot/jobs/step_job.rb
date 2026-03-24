# frozen_string_literal: true

module Rubot
  class StepJob < BaseJob
    queue_as { Rubot.configuration.step_job_queue_name }

    def perform(run_id)
      run = load_run!(run_id)
      raise ExecutionError, "StepJob only supports workflow runs" unless run.kind == :workflow
      return if run.cancel_requested? || run.canceled?

      Rubot::Executor.new.execute_run(run)
    end
  end if defined?(Rubot::BaseJob)
end
