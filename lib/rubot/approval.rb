# frozen_string_literal: true

module Rubot
  class Approval
    STATUSES = %i[pending approved rejected changes_requested expired].freeze

    attr_reader :step_name, :status, :role_requirement, :reason, :decision_payload, :decided_at,
                :assigned_to_type, :assigned_to_id, :sla_due_at, :expires_at

    def initialize(step_name:, role_requirement: nil, reason: nil, status: :pending, decision_payload: nil,
                   decided_at: nil, assigned_to: nil, assigned_to_type: nil, assigned_to_id: nil,
                   sla_due_at: nil, expires_at: nil)
      @step_name = step_name
      @role_requirement = role_requirement
      @reason = reason
      @status = status.to_sym
      @decision_payload = decision_payload
      @decided_at = decided_at
      @assigned_to_type, @assigned_to_id = normalize_assignment(assigned_to, assigned_to_type, assigned_to_id)
      @sla_due_at = sla_due_at
      @expires_at = expires_at
    end

    def approve!(payload = {})
      decide!(:approved, payload)
    end

    def reject!(payload = {})
      decide!(:rejected, payload)
    end

    def request_changes!(payload = {})
      decide!(:changes_requested, payload)
    end

    def expire!
      @status = :expired
      @decided_at ||= Rubot.configuration.time_source.call
      self
    end

    def pending?
      status == :pending
    end

    def role
      role_requirement
    end

    def assigned_to
      return if assigned_to_type.nil? && assigned_to_id.nil?

      {
        type: assigned_to_type,
        id: assigned_to_id
      }.compact
    end

    def overdue?(time = Rubot.configuration.time_source.call)
      sla_due_at && pending? && time >= sla_due_at
    end

    def expired?(time = Rubot.configuration.time_source.call)
      return status == :expired if expires_at.nil?

      status == :expired || (pending? && time >= expires_at)
    end

    def to_h
      {
        step_name: step_name,
        status: status,
        role: role,
        assigned_to_type: assigned_to_type,
        assigned_to_id: assigned_to_id,
        assigned_to: assigned_to,
        role_requirement: role_requirement,
        reason: reason,
        sla_due_at: sla_due_at&.iso8601,
        expires_at: expires_at&.iso8601,
        decision_payload: decision_payload,
        decided_at: decided_at&.iso8601
      }
    end

    private

    def normalize_assignment(assigned_to, assigned_to_type, assigned_to_id)
      return [assigned_to_type, assigned_to_id] if assigned_to.nil?

      if assigned_to.respond_to?(:id)
        [assigned_to.class.name, assigned_to.id.to_s]
      else
        ["String", assigned_to.to_s]
      end
    end

    def decide!(status, payload)
      @status = status
      @decision_payload = payload
      @decided_at = Rubot.configuration.time_source.call
      self
    end
  end
end
