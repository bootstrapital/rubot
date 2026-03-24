# frozen_string_literal: true

module Rubot
  module Records
    class ApprovalRecord < BaseRecord
      attributes :id, :run_record_id, :step_name, :status, :assigned_to_type, :assigned_to_id,
                 :role_requirement, :reason, :sla_due_at, :expires_at, :decision_payload, :decided_at
    end
  end
end
