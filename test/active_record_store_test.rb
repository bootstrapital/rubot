# frozen_string_literal: true

require_relative "test_helper"

require "active_record"
require "sqlite3"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  suppress_messages do
    create_table :rubot_run_records, id: :string, force: true do |t|
      t.string :workflow_name
      t.string :agent_name
      t.string :status, null: false
      t.string :current_step
      t.string :subject_type
      t.string :subject_id
      t.json :input_payload, default: {}
      t.json :context_payload, default: {}
      t.json :state_payload, default: {}
      t.json :output_payload
      t.json :error_payload
      t.datetime :started_at
      t.datetime :completed_at
      t.bigint :created_by_id
      t.string :correlation_id
      t.timestamps
    end

    create_table :rubot_event_records, force: true do |t|
      t.string :run_record_id, null: false
      t.string :event_type, null: false
      t.string :step_name
      t.json :payload, default: {}
      t.timestamps
    end

    create_table :rubot_tool_call_records, force: true do |t|
      t.string :run_record_id, null: false
      t.string :tool_name, null: false
      t.string :status, null: false
      t.json :input_payload, default: {}
      t.json :output_payload
      t.json :error_payload
      t.integer :duration_ms
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    create_table :rubot_approval_records, force: true do |t|
      t.string :run_record_id, null: false
      t.string :step_name, null: false
      t.string :status, null: false
      t.string :assigned_to_type
      t.string :assigned_to_id
      t.string :role_requirement
      t.text :reason
      t.datetime :sla_due_at
      t.datetime :expires_at
      t.json :decision_payload
      t.datetime :decided_at
      t.timestamps
    end
  end
end

require_relative "../app/models/rubot/application_record"
require_relative "../app/models/rubot/run_record"
require_relative "../app/models/rubot/event_record"
require_relative "../app/models/rubot/tool_call_record"
require_relative "../app/models/rubot/approval_record"

class ActiveRecordStoreWorkflow < Rubot::Workflow
  step :prepare
  approval_step :review,
                role: "ops_manager",
                reason: "Needs human review",
                assigned_to: ->(_input, _state, context) { context[:assignee] },
                sla_seconds: 300,
                expires_in: 600
  step :finish

  def prepare
    run.state[:prepare] = { ok: true }
  end

  def finish
    run.state[:finish] = { approved: true }
  end
end

class ActiveRecordStoreTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::ActiveRecordStore.new
    end

    [Rubot::EventRecord, Rubot::ToolCallRecord, Rubot::ApprovalRecord, Rubot::RunRecord].each(&:delete_all)
  end

  def teardown
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_persists_and_hydrates_runs
    now = Time.utc(2026, 3, 24, 12, 0, 0)
    Rubot.configure do |config|
      config.time_source = -> { now }
    end

    run = Rubot.run(ActiveRecordStoreWorkflow, input: { ticket_id: "t_123" }, context: { source: "test", assignee: "ops@example.com" })

    persisted = Rubot.store.find_run(run.id)

    assert_equal run.id, persisted.id
    assert_equal :waiting_for_approval, persisted.status
    assert_equal({ ticket_id: "t_123" }, persisted.input)
    assert_equal({ source: "test", assignee: "ops@example.com" }, persisted.context)
    assert_equal true, persisted.state[:prepare][:ok]
    assert_equal 5, persisted.events.length
    assert_equal "review", persisted.approvals.first.step_name
    assert_equal "String", persisted.approvals.first.assigned_to_type
    assert_equal "ops@example.com", persisted.approvals.first.assigned_to_id
    assert_equal now + 300, persisted.approvals.first.sla_due_at
    assert_equal now + 600, persisted.approvals.first.expires_at

    persisted.approve!(approved_by: "ops@example.com")
    Rubot::Executor.new.resume(ActiveRecordStoreWorkflow, persisted)

    completed = Rubot.store.find_run(run.id)

    assert_equal :completed, completed.status
    assert_equal true, completed.output[:finish][:approved]
    assert_equal "ops@example.com", completed.approvals.first.decision_payload[:approved_by]
  end
end
