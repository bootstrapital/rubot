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

class OperationTest < Minitest::Test
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

  def test_operation_enqueue_uses_configured_async_path
    calls = []

    Rubot.stub(:enqueue, ->(runnable, input:, subject:, context:) { calls << { runnable:, input:, subject:, context: } }) do
      ExistingWorkflowOperation.enqueue(
        trigger: :webhook,
        payload: { body: "async", account_id: "acct_456" },
        subject: :subject_ref
      )
    end

    assert_equal 1, calls.length
    assert_equal OperationWorkflow, calls.first[:runnable]
    assert_equal({ value: "async" }, calls.first[:input])
    assert_equal :subject_ref, calls.first[:subject]
    assert_equal({ account_id: "acct_456" }, calls.first[:context])
  end
end
