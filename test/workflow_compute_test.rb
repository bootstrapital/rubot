# frozen_string_literal: true

require_relative "test_helper"

class ComputeWorkflow < Rubot::Workflow
  compute :set_value do |input, state, context|
    state[:computed_value] = "#{input[:val]}:#{context[:ctx]}"
  end

  step :check_args do |input, state, context|
    state[:step_args] = [input[:val], state[:computed_value], context[:ctx]]
  end

  output :computed_value, :step_args
end

class WorkflowComputeTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_compute_step_executes_block_with_correct_args
    run = Rubot.run(ComputeWorkflow, input: { val: "abc" }, context: { ctx: "123" })

    assert_equal :completed, run.status
    assert_equal "abc:123", run.output[:computed_value]
    assert_equal ["abc", "abc:123", "123"], run.output[:step_args]
  end
end
