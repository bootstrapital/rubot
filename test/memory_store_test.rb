# frozen_string_literal: true

require_relative "test_helper"

class MemoryStoreWorkflow < Rubot::Workflow
  step :prepare
  approval_step :review
  step :finish

  def prepare
    run.state[:prepare] = { ok: true }
  end

  def finish
    run.state[:finish] = { ok: true }
  end
end

class MemoryStoreTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_store_tracks_runs_and_pending_approvals
    run = Rubot.run(MemoryStoreWorkflow, input: {})

    assert_same run, Rubot.store.find_run(run.id)
    assert_includes Rubot.store.all_runs, run
    assert_includes Rubot.store.pending_approvals, run

    run.approve!(approved_by: "ops@example.com")
    Rubot::Executor.new.resume(MemoryStoreWorkflow, run)

    refute_includes Rubot.store.pending_approvals, run
    assert_equal :completed, Rubot.store.find_run(run.id).status
  end
end
