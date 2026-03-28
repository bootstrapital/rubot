# frozen_string_literal: true

module YamlConfigOperationExample
  class LoadAccountSnapshotTool < Rubot::Tool
    description "Load a simple account snapshot."

    input_schema do
      string :account_id
    end

    output_schema do
      string :account_id
      string :status
      string :segment
      string :recent_activity
    end

    def call(account_id:)
      {
        account_id: account_id,
        status: account_id.end_with?("9") ? "delinquent" : "active",
        segment: "mid_market",
        recent_activity: "two invoice follow-ups"
      }
    end
  end
end
