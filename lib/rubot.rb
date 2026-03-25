# frozen_string_literal: true

require "json"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/string/inflections"
require "securerandom"
require "time"
require "globalid"

require_relative "rubot/version"
require_relative "rubot/hash_utils"
require_relative "rubot/errors"
require_relative "rubot/configuration"
require_relative "rubot/metrics"
require_relative "rubot/subject"
require_relative "rubot/memory"
require_relative "rubot/policy"
require_relative "rubot/schema"
require_relative "rubot/eval"
require_relative "rubot/step_definition"
require_relative "rubot/event"
require_relative "rubot/approval"
require_relative "rubot/run"
require_relative "rubot/live_updates"
require_relative "rubot/dsl"
require_relative "rubot/middleware"
require_relative "rubot/agent_resolution_context"
require_relative "rubot/trigger"
require_relative "rubot/tool"
require_relative "rubot/tools/file_actions"
require_relative "rubot/agent"
require_relative "rubot/workflow"
require_relative "rubot/operation"
require_relative "rubot/playground"
require_relative "rubot/executor"
require_relative "rubot/async"
require_relative "rubot/mcp"
require_relative "rubot/providers/base"
require_relative "rubot/providers/result"
require_relative "rubot/providers/ruby_llm"
require_relative "rubot/stores/base"
require_relative "rubot/stores/memory_store"
require_relative "rubot/stores/active_record_store"
require_relative "rubot/jobs/base_job"
require_relative "rubot/jobs/run_job"
require_relative "rubot/jobs/step_job"
require_relative "rubot/jobs/resume_run_job"
require_relative "rubot/presenters/run_presenter"
require_relative "rubot/presenters/approval_presenter"
require_relative "rubot/presenters/tool_call_presenter"
require_relative "rubot/records/base_record"
require_relative "rubot/records/run_record"
require_relative "rubot/records/tool_call_record"
require_relative "rubot/records/event_record"
require_relative "rubot/records/approval_record"

module Rubot
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def store
      configuration.store ||= Stores::MemoryStore.new
    end

    def provider
      configuration.provider
    end

    def run(workflow_or_agent, input: {}, subject: nil, context: {}, trace_id: nil, replay_of_run_id: nil)
      Executor.new.call(workflow_or_agent, input: input, subject: subject, context: context, trace_id:, replay_of_run_id:)
    end

    def run_for(subject, workflow_or_agent, input: {}, context: {}, trace_id: nil, replay_of_run_id: nil)
      run(workflow_or_agent, input:, subject:, context:, trace_id:, replay_of_run_id:)
    end

    def enqueue(workflow_or_agent, input: {}, subject: nil, context: {}, trace_id: nil, replay_of_run_id: nil)
      Async.enqueue(workflow_or_agent, input:, subject:, context:, trace_id:, replay_of_run_id:)
    end

    def enqueue_for(subject, workflow_or_agent, input: {}, context: {}, trace_id: nil, replay_of_run_id: nil)
      enqueue(workflow_or_agent, input:, subject:, context:, trace_id:, replay_of_run_id:)
    end

    def resume_later(run_or_id)
      Async.resume_later(run_or_id)
    end

    def replay(run_or_id)
      Executor.new.replay(run_or_id)
    end
  end
end

require_relative "rubot/engine" if defined?(Rails::Engine)
require_relative "rubot/railtie" if defined?(Rails::Railtie)
