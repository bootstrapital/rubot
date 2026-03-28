# frozen_string_literal: true

require_relative "test_helper"

class WorkflowOutputEchoTool < Rubot::Tool
  input_schema do
    string :value
  end

  output_schema do
    string :value
  end

  def call(value:)
    { value: value }
  end
end

class WorkflowOutputSingleKeyWorkflow < Rubot::Workflow
  tool_step :echo, tool: WorkflowOutputEchoTool
  output :echo
end

class WorkflowOutputSliceWorkflow < Rubot::Workflow
  tool_step :first, tool: WorkflowOutputEchoTool, input: { value: "first" }
  tool_step :second, tool: WorkflowOutputEchoTool, input: { value: "second" }
  output :first, :second
end

class WorkflowOutputBlockWorkflow < Rubot::Workflow
  tool_step :echo, tool: WorkflowOutputEchoTool

  output do |input, state, context, _run|
    {
      echoed: state.fetch(:echo).fetch(:value),
      original: input.fetch(:value),
      source: context.fetch(:source)
    }
  end
end

class WorkflowOutputFinalizeWorkflow < Rubot::Workflow
  tool_step :echo, tool: WorkflowOutputEchoTool

  step :finalize

  def finalize
    run.state[:finalize] = { wrapped: run.state.fetch(:echo).fetch(:value) }
  end
end

class WorkflowOutputHelpersTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_output_can_expose_single_step_result_directly
    run = Rubot.run(WorkflowOutputSingleKeyWorkflow, input: { value: "abc" })

    assert_equal :completed, run.status
    assert_equal({ value: "abc" }, run.output)
  end

  def test_output_can_select_multiple_state_keys
    run = Rubot.run(WorkflowOutputSliceWorkflow, input: { value: "ignored" })

    assert_equal(
      {
        first: { value: "first" },
        second: { value: "second" }
      },
      run.output
    )
  end

  def test_output_can_use_lightweight_shaping_block
    run = Rubot.run(WorkflowOutputBlockWorkflow, input: { value: "abc" }, context: { source: "email" })

    assert_equal(
      {
        echoed: "abc",
        original: "abc",
        source: "email"
      },
      run.output
    )
  end

  def test_workflows_without_output_helper_keep_existing_snapshot_behavior
    run = Rubot.run(WorkflowOutputFinalizeWorkflow, input: { value: "abc" })

    assert_equal(
      {
        echo: { value: "abc" },
        finalize: { wrapped: "abc" }
      },
      run.output
    )
    assert_nil run.output[:_rubot]
    assert_nil run.output["_rubot"]
  end
end
