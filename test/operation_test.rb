# frozen_string_literal: true

require_relative "test_helper"

class OperationWorkflow < Rubot::Workflow
  step :finish

  def finish
    run.state[:finish] = { payload: run.input[:value], account: run.context[:account_id] }
  end
end

class ExistingWorkflowOperation < Rubot::Operation
  workflow OperationWorkflow
  trigger :manual
  trigger :webhook,
          input: ->(payload, _subject, _context) { { value: payload[:body] } },
          context: ->(payload, _subject, context) { context.merge(account_id: payload[:account_id]) }
end

class InlineOperation < Rubot::Operation
  tool :lookup do
    input_schema do
      string :value
    end

    output_schema do
      string :value
    end

    def call(value:)
      { value: "seen:#{value}" }
    end
  end

  workflow do
    tool_step :lookup_value,
              tool: LookupTool,
              input: ->(input, _state, _context) { { value: input[:value] } }
  end

  trigger :manual
end

class MultiWorkflowOperation < Rubot::Operation
  tool :normalize do
    input_schema do
      string :value
    end

    output_schema do
      string :value
    end

    def call(value:)
      { value: "normalized:#{value}" }
    end
  end

  agent :summarize do
    input_schema do
      string :value
    end

    output_schema do
      string :summary
    end

    def perform(input:, run:, context:)
      { summary: "summary:#{input[:value]}:#{context[:mode]}" }
    end
  end

  workflow :current_state, default: true do
    tool_step :normalize_value,
              tool: :normalize,
              input: ->(input, _state, _context) { { value: input[:value] } }

    agent_step :summarize_value,
               agent: :summarize,
               input: ->(_input, state, _context) { state.fetch(:normalize_value) }

    step :finalize

    def finalize
      run.state[:finalize] = {
        mode: run.context[:mode],
        summary: run.state.fetch(:summarize_value)
      }
    end
  end

  workflow :future_state do
    step :finish

    def finish
      run.state[:finish] = {
        mode: run.context[:mode],
        value: "future:#{run.input[:value]}"
      }
    end
  end

  trigger :manual, context: ->(_payload, _subject, context) { context.merge(mode: "current") }
  trigger :future_state_design,
          workflow: :future_state,
          context: ->(_payload, _subject, context) { context.merge(mode: "future") }

  entrypoint :current_state, workflow: :current_state
  entrypoint :future_state, trigger: :future_state_design
  entrypoint :expedited_future_state,
             workflow: :future_state,
             input: ->(input, _subject, _context) { input.merge(value: "expedited:#{input[:value]}") },
             context: ->(_input, _subject, context) { context.merge(mode: "expedited") }
end

class LateBindingOperation < Rubot::Operation
  workflow :test_late_binding do
    tool_step :late_tool_step, tool: :late_tool, input: { value: "a" }
    agent_step :late_agent_step, agent: :late_agent, input: { value: "b" }
    output :late_tool_step, :late_agent_step
  end

  tool :late_tool do
    input_schema { string :value }
    output_schema { string :result }
    def call(value:)
      { result: "tool:#{value}" }
    end
  end

  agent :late_agent do
    input_schema { string :value }
    output_schema { string :result }
    def perform(input:, run:, context:)
      { result: "agent:#{input[:value]}" }
    end
  end
end

class OperationTest < Minitest::Test
  def test_operation_supports_late_binding_of_tools_and_agents
    run = LateBindingOperation.launch(workflow: :test_late_binding)

    assert_equal :completed, run.status
    assert_equal "tool:a", run.output[:late_tool_step][:result]
    assert_equal "agent:b", run.output[:late_agent_step][:result]
  end

  def test_operation_launch_uses_trigger_resolution
    run = ExistingWorkflowOperation.launch(
      trigger: :webhook,
      payload: { body: "abc", account_id: "acct_123" }
    )

    assert_equal :completed, run.status
    assert_equal "abc", run.output[:finish][:payload]
    assert_equal "acct_123", run.output[:finish][:account]
  end

  def test_operation_supports_inline_single_file_workflow_authoring
    run = InlineOperation.launch(payload: { value: "abc" })

    assert_equal :completed, run.status
    assert_equal "seen:abc", run.output[:lookup_value][:value]
    assert_equal InlineOperation::LookupTool, InlineOperation.tools.first
    assert_equal InlineOperation::Workflow, InlineOperation.workflow
  end

  def test_operation_supports_named_inline_workflows_and_symbol_component_references
    run = MultiWorkflowOperation.launch(payload: { value: "abc" })

    assert_equal :completed, run.status
    assert_equal "current", run.output[:finalize][:mode]
    assert_equal "summary:normalized:abc:current", run.output[:finalize][:summary][:summary]
    assert_equal MultiWorkflowOperation.workflow, MultiWorkflowOperation.workflow(:current_state)
    assert_equal MultiWorkflowOperation.tool(:normalize), MultiWorkflowOperation.tools.first
    assert_equal MultiWorkflowOperation.agent(:summarize), MultiWorkflowOperation.agent
  end

  def test_operation_can_launch_named_workflow_explicitly
    run = MultiWorkflowOperation.launch(workflow: :future_state, payload: { value: "abc" }, context: { mode: "override" })

    assert_equal :completed, run.status
    assert_equal "override", run.output[:finish][:mode]
    assert_equal "future:abc", run.output[:finish][:value]
  end

  def test_operation_trigger_can_route_to_named_workflow
    run = MultiWorkflowOperation.launch(trigger: :future_state_design, payload: { value: "abc" })

    assert_equal :completed, run.status
    assert_equal "future", run.output[:finish][:mode]
    assert_equal "future:abc", run.output[:finish][:value]
  end

  def test_operation_entrypoint_can_launch_named_workflow
    run = MultiWorkflowOperation.launch(entrypoint: :current_state, payload: { value: "abc" }, context: { mode: "override" })

    assert_equal :completed, run.status
    assert_equal "override", run.output[:finalize][:mode]
    assert_equal "summary:normalized:abc:override", run.output[:finalize][:summary][:summary]
  end

  def test_operation_entrypoint_can_route_through_trigger
    run = MultiWorkflowOperation.launch_future_state(payload: { value: "abc" })

    assert_equal :completed, run.status
    assert_equal "future", run.output[:finish][:mode]
    assert_equal "future:abc", run.output[:finish][:value]
  end

  def test_operation_entrypoint_can_apply_input_and_context_shaping
    run = MultiWorkflowOperation.launch(entrypoint: :expedited_future_state, payload: { value: "abc" })

    assert_equal :completed, run.status
    assert_equal "expedited", run.output[:finish][:mode]
    assert_equal "future:expedited:abc", run.output[:finish][:value]
  end

  def test_operation_enqueue_uses_configured_async_path
    calls = []
    rubot_singleton = class << Rubot; self; end

    original_enqueue = Rubot.method(:enqueue)
    rubot_singleton.send(:remove_method, :enqueue)
    rubot_singleton.send(:define_method, :enqueue) do |runnable, input:, subject:, context:, **_options|
      calls << { runnable:, input:, subject:, context: }
    end

    ExistingWorkflowOperation.enqueue(
      trigger: :webhook,
      payload: { body: "async", account_id: "acct_456" },
      subject: :subject_ref
    )
  ensure
    rubot_singleton.send(:remove_method, :enqueue) if rubot_singleton.method_defined?(:enqueue)
    rubot_singleton.send(:define_method, :enqueue, original_enqueue)

    assert_equal 1, calls.length
    assert_equal OperationWorkflow, calls.first[:runnable]
    assert_equal({ value: "async" }, calls.first[:input])
    assert_equal :subject_ref, calls.first[:subject]
    assert_equal({ account_id: "acct_456" }, calls.first[:context])
  end

  def test_operation_enqueue_uses_named_workflow_from_trigger
    calls = []
    rubot_singleton = class << Rubot; self; end

    original_enqueue = Rubot.method(:enqueue)
    rubot_singleton.send(:remove_method, :enqueue)
    rubot_singleton.send(:define_method, :enqueue) do |runnable, input:, subject:, context:, **_options|
      calls << { runnable:, input:, subject:, context: }
    end

    MultiWorkflowOperation.enqueue(trigger: :future_state_design, payload: { value: "queued" })
  ensure
    rubot_singleton.send(:remove_method, :enqueue) if rubot_singleton.method_defined?(:enqueue)
    rubot_singleton.send(:define_method, :enqueue, original_enqueue)

    assert_equal 1, calls.length
    assert_equal MultiWorkflowOperation.workflow(:future_state), calls.first[:runnable]
    assert_equal({ value: "queued" }, calls.first[:input])
    assert_equal({ mode: "future" }, calls.first[:context])
  end

  def test_operation_entrypoint_enqueue_helper_uses_entrypoint_resolution
    calls = []
    rubot_singleton = class << Rubot; self; end

    original_enqueue = Rubot.method(:enqueue)
    rubot_singleton.send(:remove_method, :enqueue)
    rubot_singleton.send(:define_method, :enqueue) do |runnable, input:, subject:, context:, **_options|
      calls << { runnable:, input:, subject:, context: }
    end

    MultiWorkflowOperation.enqueue_expedited_future_state(payload: { value: "queued" })
  ensure
    rubot_singleton.send(:remove_method, :enqueue) if rubot_singleton.method_defined?(:enqueue)
    rubot_singleton.send(:define_method, :enqueue, original_enqueue)

    assert_equal 1, calls.length
    assert_equal MultiWorkflowOperation.workflow(:future_state), calls.first[:runnable]
    assert_equal({ value: "expedited:queued" }, calls.first[:input])
    assert_equal({ mode: "expedited" }, calls.first[:context])
  end
end
