# frozen_string_literal: true

require_relative "test_helper"

class FlakyIdempotentTool < Rubot::Tool
  idempotent!
  retry_on RuntimeError, attempts: 2

  input_schema do
    string :value
  end

  output_schema do
    string :value
  end

  def call(value:)
    raise "boom" if value == "explode"

    { value: value }
  end
end

class CheckpointWorkflow < Rubot::Workflow
  tool_step :work, tool: FlakyIdempotentTool
end

class ConcurrencyTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_retryable_tool_errors_are_wrapped
    run = Rubot::Run.new(name: CheckpointWorkflow.name, kind: :workflow, input: { value: "explode" }, persist: false)

    error = assert_raises(Rubot::RetryableError) do
      FlakyIdempotentTool.new.execute(input: { value: "explode" }, run: run)
    end

    assert_equal :tool_retryable, error.category
    assert_equal "FlakyIdempotentTool", error.details[:tool_name]
  end

  def test_run_can_be_canceled_before_execution
    run = Rubot::Run.new(name: CheckpointWorkflow.name, kind: :workflow, input: { value: "abc" })
    run.request_cancellation!(reason: "operator canceled")

    Rubot::Executor.new.execute_run(run)

    assert_equal :canceled, run.status
    assert_includes run.events.map(&:type), "run.canceled"
  end

  def test_workflow_records_step_checkpoints
    run = Rubot.run(CheckpointWorkflow, input: { value: "abc" })
    checkpoint = run.checkpoint_for(:work)

    assert_equal "completed", checkpoint[:status]
    assert_equal "tool_step", checkpoint[:kind]
  end
end
