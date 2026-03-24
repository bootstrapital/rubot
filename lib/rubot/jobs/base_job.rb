# frozen_string_literal: true

begin
  require "active_job"
rescue LoadError
  nil
end

module Rubot
  class BaseJob < ActiveJob::Base
    retry_on Rubot::RetryableError, Rubot::ConcurrencyError, wait: 1, attempts: -> { Rubot.configuration.job_retry_attempts }
    discard_on Rubot::ApprovalRequired
    discard_on Rubot::CancellationError

    private

    def load_run!(run_id)
      Rubot.store.find_run(run_id) || raise(ExecutionError, "Run #{run_id} was not found in #{Rubot.store.class.name}")
    end
  end if defined?(ActiveJob::Base)
end
