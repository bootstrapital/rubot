# frozen_string_literal: true

module Rubot
  module Records
    class RunRecord < BaseRecord
      attributes :id, :workflow_name, :agent_name, :status, :current_step, :subject_type,
                 :subject_id, :input_payload, :state_payload, :output_payload, :error_payload,
                 :started_at, :completed_at, :created_by_id, :correlation_id
    end
  end
end
