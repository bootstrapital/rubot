# frozen_string_literal: true

module Rubot
  module Records
    class ToolCallRecord < BaseRecord
      attributes :id, :run_record_id, :tool_name, :status, :input_payload, :output_payload,
                 :error_payload, :duration_ms, :started_at, :completed_at
    end
  end
end
