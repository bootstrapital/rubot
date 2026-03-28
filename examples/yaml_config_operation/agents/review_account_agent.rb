# frozen_string_literal: true

module YamlConfigOperationExample
  class ReviewAccountAgent < Rubot::Agent
    input_schema do
      string :account_id
      string :status
      string :segment
      string :recent_activity
    end

    output_schema do
      string :recommended_action
      string :summary
    end

    def perform(input:, run:, context:)
      action =
        if input[:status] == "delinquent"
          "escalate"
        else
          context.fetch(:default_action, "monitor")
        end

      {
        recommended_action: action,
        summary: "#{input[:segment]} account #{input[:account_id]} is #{input[:status]} with #{input[:recent_activity]}"
      }
    end
  end
end
