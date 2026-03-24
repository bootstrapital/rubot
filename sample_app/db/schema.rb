# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_03_24_070906) do
  create_table "rubot_approval_records", force: :cascade do |t|
    t.string "run_record_id", null: false
    t.string "step_name", null: false
    t.string "status", null: false
    t.string "assigned_to_type"
    t.string "assigned_to_id"
    t.string "role_requirement"
    t.text "reason"
    t.datetime "sla_due_at"
    t.datetime "expires_at"
    t.json "decision_payload"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["run_record_id"], name: "index_rubot_approval_records_on_run_record_id"
    t.index ["status"], name: "index_rubot_approval_records_on_status"
  end

  create_table "rubot_event_records", force: :cascade do |t|
    t.string "run_record_id", null: false
    t.string "event_type", null: false
    t.string "step_name"
    t.json "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_rubot_event_records_on_event_type"
    t.index ["run_record_id"], name: "index_rubot_event_records_on_run_record_id"
  end

  create_table "rubot_run_records", id: :string, force: :cascade do |t|
    t.string "workflow_name"
    t.string "agent_name"
    t.string "status", null: false
    t.string "current_step"
    t.string "subject_type"
    t.string "subject_id"
    t.json "input_payload", default: {}, null: false
    t.json "context_payload", default: {}, null: false
    t.json "state_payload", default: {}, null: false
    t.json "output_payload"
    t.json "error_payload"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.bigint "created_by_id"
    t.string "correlation_id"
    t.string "replay_of_run_id"
    t.datetime "cancellation_requested_at"
    t.datetime "canceled_at"
    t.string "execution_claim_token"
    t.datetime "execution_claimed_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["correlation_id"], name: "index_rubot_run_records_on_correlation_id"
    t.index ["execution_claim_token"], name: "index_rubot_run_records_on_execution_claim_token"
    t.index ["replay_of_run_id"], name: "index_rubot_run_records_on_replay_of_run_id"
    t.index ["status"], name: "index_rubot_run_records_on_status"
    t.index ["subject_type", "subject_id"], name: "index_rubot_run_records_on_subject_type_and_subject_id"
  end

  create_table "rubot_tool_call_records", force: :cascade do |t|
    t.string "run_record_id", null: false
    t.string "tool_name", null: false
    t.string "status", null: false
    t.json "input_payload", default: {}, null: false
    t.json "output_payload"
    t.json "error_payload"
    t.integer "duration_ms"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["run_record_id"], name: "index_rubot_tool_call_records_on_run_record_id"
    t.index ["tool_name"], name: "index_rubot_tool_call_records_on_tool_name"
  end

end
