# frozen_string_literal: true

require_relative "test_helper"

class LiveUpdatesWorkflow < Rubot::Workflow
  step :prepare
  approval_step :review, role: "reviewer", reason: "Needs a human"

  def prepare
    run.state[:prepare] = { ok: true }
  end
end

class LiveUpdatesBroadcaster < Rubot::LiveUpdates::Broadcaster
  attr_reader :calls

  def initialize
    @calls = []
  end

  def enabled?
    true
  end

  private

  def render(partial, locals)
    { partial:, keys: locals.keys.sort }
  end

  def broadcast_replace_to(stream, target:, html:)
    calls << { stream:, target:, html: }
  end
end

class LiveUpdatesTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_run_persist_triggers_live_update_broadcast
    calls = []
    run = Rubot::Run.new(name: "ExampleAgent", kind: :agent, input: {}, persist: false)

    Rubot::LiveUpdates.stub(:broadcast_run, ->(persisted_run) { calls << persisted_run.id }) do
      run.persist!
    end

    assert_equal [run.id], calls
  end

  def test_broadcaster_replaces_run_and_approval_targets
    run = Rubot.run(LiveUpdatesWorkflow, input: { ticket_id: "t_1" })
    broadcaster = LiveUpdatesBroadcaster.new

    broadcaster.broadcast_run(run)

    targets = broadcaster.calls.map { |call| call[:target] }

    assert_includes targets, Rubot::LiveUpdates.runs_table_dom_id
    assert_includes targets, Rubot::LiveUpdates.approvals_inbox_dom_id
    assert_includes targets, Rubot::LiveUpdates.run_overview_dom_id(run.id)
    assert_includes targets, Rubot::LiveUpdates.run_output_dom_id(run.id)
    assert_includes targets, Rubot::LiveUpdates.run_pending_approval_dom_id(run.id)
    assert_includes targets, Rubot::LiveUpdates.run_timeline_dom_id(run.id)
  end
end
