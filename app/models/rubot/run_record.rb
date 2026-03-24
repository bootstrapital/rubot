# frozen_string_literal: true

module Rubot
  class RunRecord < ApplicationRecord
    self.table_name = "rubot_run_records"

    has_many :event_records, class_name: "Rubot::EventRecord", foreign_key: :run_record_id, dependent: :delete_all, inverse_of: :run_record
    has_many :tool_call_records, class_name: "Rubot::ToolCallRecord", foreign_key: :run_record_id, dependent: :delete_all, inverse_of: :run_record
    has_many :approval_records, class_name: "Rubot::ApprovalRecord", foreign_key: :run_record_id, dependent: :delete_all, inverse_of: :run_record
    belongs_to :replayed_from, class_name: "Rubot::RunRecord", foreign_key: :replay_of_run_id, optional: true
  end
end
