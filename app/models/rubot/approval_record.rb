# frozen_string_literal: true

module Rubot
  class ApprovalRecord < ApplicationRecord
    self.table_name = "rubot_approval_records"

    belongs_to :run_record, class_name: "Rubot::RunRecord", inverse_of: :approval_records
  end
end
