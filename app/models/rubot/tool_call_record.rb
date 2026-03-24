# frozen_string_literal: true

module Rubot
  class ToolCallRecord < ApplicationRecord
    self.table_name = "rubot_tool_call_records"

    belongs_to :run_record, class_name: "Rubot::RunRecord", inverse_of: :tool_call_records
  end
end
