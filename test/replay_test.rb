# frozen_string_literal: true

require_relative "test_helper"

class ReplayWorkflow < Rubot::Workflow
  step :prepare

  def prepare
    run.state[:prepare] = {
      echoed_input: run.input,
      echoed_context: run.context
    }
  end
end

class ReplayTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_replay_copies_input_and_context_and_links_runs
    original = Rubot.run(ReplayWorkflow, input: { ticket_id: "t_123" }, context: { source: "test" })
    replay = Rubot.replay(original)

    refute_equal original.id, replay.id
    assert_equal original.input, replay.input
    assert_equal original.context, replay.context
    assert_equal original.trace_id, replay.trace_id
    assert_equal original.id, replay.replay_of_run_id
    assert_equal original.output, replay.output
  end
end
