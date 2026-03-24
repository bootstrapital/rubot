# frozen_string_literal: true

module Rubot
  class RunJob < BaseJob
    queue_as { Rubot.configuration.run_job_queue_name }

    def perform(run_id)
      run = load_run!(run_id)

      case run.kind
      when :workflow
        Rubot::StepJob.perform_later(run.id)
      when :agent
        Rubot::Executor.new.execute_run(run)
      else
        raise ExecutionError, "Unsupported run kind #{run.kind}"
      end
    end
  end if defined?(Rubot::BaseJob)
end
