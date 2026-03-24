# frozen_string_literal: true

module Rubot
  class Executor
    def call(workflow_or_agent, input:, subject: nil, context: {})
      run = build_run(workflow_or_agent, input:, subject:, context:)
      execute_run(run, runnable: workflow_or_agent)
    end

    def resume(workflow_class, run)
      run.start! unless run.running?
      workflow_class.new(run:).resume
      append_completed_event(run)
      run
    end

    private

    def build_run(workflow_or_agent, input:, subject:, context:)
      klass = workflow_or_agent.is_a?(Class) ? workflow_or_agent : workflow_or_agent.class
      Run.new(name: klass.name, kind: infer_kind(klass), input:, subject:, context:)
    end

    public

    def execute_run(run, runnable: nil)
      klass = resolve_runnable(run, runnable)
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
    rescue StandardError => e
      unless run&.failed?
        run&.fail!(class: e.class.name, message: e.message)
        run&.add_event(Event.new(type: "run.failed", step_name: run&.current_step, payload: { error_class: e.class.name, error_message: e.message }))
      end
      raise
    end

    private

    def infer_kind(klass)
      return :workflow if klass < Workflow
      return :agent if klass < Agent

      raise ExecutionError, "Runnable must inherit from Rubot::Workflow or Rubot::Agent"
    end

    def resolve_runnable(run, runnable)
      klass = runnable.is_a?(Class) ? runnable : runnable&.class
      klass ||= Object.const_get(run.name)
      expected_kind = infer_kind(klass)
      return klass if expected_kind == run.kind

      raise ExecutionError, "Run #{run.id} kind #{run.kind} does not match #{klass.name}"
    rescue NameError => e
      raise ExecutionError, "Unable to resolve runnable #{run.name}: #{e.message}"
    end

    def ensure_run_started!(run)
      return if run.started_at

      run.add_event(Event.new(type: "run.started", payload: { name: run.name, kind: run.kind, input: run.input, subject: run.subject }))
      run.start!
    end

    def execute_workflow(klass, run)
      execution = klass.new(run:)
      return execution.execute if run.current_step.nil?

      run.start! unless run.running?
      execution.resume
    end

    def execute_agent(klass, run)
      result = klass.run(input: run.input, run:, context: run.context)
      run.complete!(result)
    end

    def append_completed_event(run)
      return unless run.completed?
      return if run.events.any? { |event| event.type == "run.completed" }

      run.add_event(Event.new(type: "run.completed", step_name: run.current_step, payload: { output: run.output }))
    end
  end
end
