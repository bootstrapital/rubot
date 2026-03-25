# frozen_string_literal: true

module Rubot
  class Executor
    def call(workflow_or_agent, input:, subject: nil, context: {}, trace_id: nil, replay_of_run_id: nil)
      run = build_run(workflow_or_agent, input:, subject:, context:, trace_id:, replay_of_run_id:)
      Rubot::Policy.authorize!(
        action: :start,
        runnable: resolve_runnable(run, workflow_or_agent),
        run: run,
        subject: run.subject,
        context: run.context,
        fail_run: true
      )
      execute_run(run, runnable: workflow_or_agent)
    end

    def replay(run_or_id)
      source_run = run_or_id.is_a?(Run) ? run_or_id : Rubot.store.find_run(run_or_id)
      raise ExecutionError, "Run #{run_or_id} was not found" unless source_run

      runnable = resolve_runnable(source_run, nil)
      call(
        runnable,
        input: source_run.input,
        subject: source_run.subject,
        context: source_run.context,
        trace_id: source_run.trace_id,
        replay_of_run_id: source_run.id
      )
    end

    def resume(workflow_class, run)
      run.start! unless run.running?
      workflow_class.new(run:).resume
      append_completed_event(run)
      run
    end

    private

    def build_run(workflow_or_agent, input:, subject:, context:, trace_id: nil, replay_of_run_id: nil)
      klass = workflow_or_agent.is_a?(Class) ? workflow_or_agent : workflow_or_agent.class
      Run.new(name: klass.name, kind: infer_kind(klass), input:, subject:, context:, trace_id:, replay_of_run_id:)
    end

    public

    def execute_run(run, runnable: nil)
      run = acquire_execution_claim(run)
      return Rubot.store.find_run(run.id) || run if supports_execution_claims? && run.execution_claim_token.nil?

      klass = resolve_runnable(run, runnable)
      run.raise_if_canceled!
      ensure_run_started!(run)

      case run.kind
      when :workflow
        execute_workflow(klass, run)
      when :agent
        execute_agent(klass, run)
      else
        raise ExecutionError, "Unsupported runnable #{klass.name}"
      end

      append_completed_event(run)
      run
    rescue CancellationError => e
      run&.cancel!(reason: e.message) unless run&.canceled?
      run
    rescue StandardError => e
      unless run&.failed?
        run&.fail!(class: e.class.name, message: e.message)
        run&.add_event(Event.new(type: "run.failed", step_name: run&.current_step, payload: { error_class: e.class.name, error_message: e.message }))
      end
      raise
    ensure
      release_execution_claim(run)
    end

    private

    def infer_kind(klass)
      return :workflow if klass < Workflow
      return :agent if klass < Agent

      raise ExecutionError, "Runnable must inherit from Rubot::Workflow or Rubot::Agent"
    end

    def resolve_runnable(run, runnable)
      klass = runnable.is_a?(Class) ? runnable : runnable&.class
      klass ||= run.name.constantize
      expected_kind = infer_kind(klass)
      return klass if expected_kind == run.kind

      raise ExecutionError, "Run #{run.id} kind #{run.kind} does not match #{klass.name}"
    rescue NameError => e
      raise ExecutionError, "Unable to resolve runnable #{run.name}: #{e.message}"
    end

    def ensure_run_started!(run)
      return if run.started_at

      run.add_event(
        Event.new(
          type: "run.started",
          payload: run_event_payload(run)
        )
      )
      run.start!
    end

    def execute_workflow(klass, run)
      execution = klass.new(run:)
      return execution.execute if run.current_step.nil?

      run.start! unless run.running?
      execution.resume
    end

    def execute_agent(klass, run)
      run.raise_if_canceled!
      result = klass.run(input: run.input, run:, context: run.context)
      run.complete!(result)
    end

    def append_completed_event(run)
      return unless run.completed?
      return if run.events.any? { |event| event.type == "run.completed" }

      run.add_event(
        Event.new(
          type: "run.completed",
          step_name: run.current_step,
          payload: {
            run_id: run.id,
            runnable_name: run.runnable_name,
            output: run.output,
            trace_id: run.trace_id,
            replay_of_run_id: run.replay_of_run_id,
            source_run_id: run.source_run_id
          }.compact
        )
      )
    end

    def acquire_execution_claim(run)
      return run unless supports_execution_claims?

      claimed_run = Rubot.store.claim_run_execution(run)
      return claimed_run if claimed_run

      run.add_event(
        Event.new(
          type: "run.execution_skipped",
          step_name: run.current_step,
          payload: { reason: "claim_unavailable" }
        )
      )
      run
    rescue ConcurrencyError => e
      run.fail!(class: e.class.name, message: e.message, type: "subject_concurrency_conflict")
      run.add_event(Event.new(type: "run.concurrency_blocked", step_name: run.current_step, payload: { error_message: e.message }))
      raise
    end

    def release_execution_claim(run)
      return unless run && supports_execution_claims?

      Rubot.store.release_run_execution(run)
    end

    def supports_execution_claims?
      Rubot.store.respond_to?(:execution_claims_supported?) && Rubot.store.execution_claims_supported?
    end

    def run_event_payload(run)
      {
        run_id: run.id,
        name: run.name,
        runnable_name: run.runnable_name,
        kind: run.kind,
        run_kind: run.kind,
        input: run.input,
        subject: run.subject,
        subject_ref: run.subject_ref&.to_h,
        trace_id: run.trace_id,
        replay_of_run_id: run.replay_of_run_id,
        source_run_id: run.source_run_id
      }.compact
    end
  end
end
