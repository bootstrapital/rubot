class CreateRubotTables < ActiveRecord::Migration[7.1]
  def change
    create_table :rubot_run_records, id: :string do |t|
      t.string :workflow_name
      t.string :agent_name
      t.string :status, null: false
      t.string :current_step
      t.string :subject_type
      t.string :subject_id
      t.json :input_payload, null: false, default: {}
      t.json :context_payload, null: false, default: {}
      t.json :state_payload, null: false, default: {}
      t.json :output_payload
      t.json :error_payload
      t.datetime :started_at
      t.datetime :completed_at
      t.bigint :created_by_id
      t.string :correlation_id
      t.string :replay_of_run_id
      t.datetime :cancellation_requested_at
      t.datetime :canceled_at
      t.string :execution_claim_token
      t.datetime :execution_claimed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    create_table :rubot_event_records do |t|
      t.string :run_record_id, null: false
      t.string :event_type, null: false
      t.string :step_name
      t.json :payload, null: false, default: {}
      t.timestamps
    end

    create_table :rubot_tool_call_records do |t|
      t.string :run_record_id, null: false
      t.string :tool_name, null: false
      t.string :status, null: false
      t.json :input_payload, null: false, default: {}
      t.json :output_payload
      t.json :error_payload
      t.integer :duration_ms
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    create_table :rubot_approval_records do |t|
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

    add_index :rubot_run_records, :status
    add_index :rubot_run_records, [:subject_type, :subject_id]
    add_index :rubot_run_records, :correlation_id
    add_index :rubot_run_records, :replay_of_run_id
    add_index :rubot_run_records, :execution_claim_token

    add_index :rubot_event_records, :run_record_id
    add_index :rubot_event_records, :event_type

    add_index :rubot_tool_call_records, :run_record_id
    add_index :rubot_tool_call_records, :tool_name

    add_index :rubot_approval_records, :run_record_id
    add_index :rubot_approval_records, :status
  end
end
