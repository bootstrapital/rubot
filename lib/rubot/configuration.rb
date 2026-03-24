# frozen_string_literal: true

module Rubot
  class Configuration
    attr_accessor :event_subscriber, :time_source, :id_generator, :store, :job_retry_attempts,
                  :run_job_queue_name, :step_job_queue_name, :resume_job_queue_name,
                  :provider, :default_model, :default_provider_name, :agent_max_turns

    def initialize
      @event_subscriber = nil
      @time_source = -> { Time.now.utc }
      @id_generator = -> { SecureRandom.uuid }
      @store = nil
      @job_retry_attempts = 3
      @run_job_queue_name = :default
      @step_job_queue_name = :default
      @resume_job_queue_name = :default
      @provider = nil
      @default_model = nil
      @default_provider_name = nil
      @agent_max_turns = 6
    end
  end
end
