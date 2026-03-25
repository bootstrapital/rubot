# frozen_string_literal: true

begin
  require "active_record"
rescue LoadError
  nil
end

module Rubot
  module Stores
    class ActiveRecordStore < Base
      def save_run(run)
        ensure_active_record!

        record = Rubot::RunRecord.find_or_initialize_by(id: run.id)
        assign_run_attributes(record, run)

        ActiveRecord::Base.transaction do
          record.save!
          replace_events(record, run)
          replace_tool_calls(record, run)
          replace_approvals(record, run)
        end

        run
      end

      def find_run(run_id)
        ensure_active_record!

        record = Rubot::RunRecord.includes(:event_records, :tool_call_records, :approval_records).find_by(id: run_id)
        hydrate_run(record)
      end

      def all_runs
        ensure_active_record!

        Rubot::RunRecord.includes(:event_records, :tool_call_records, :approval_records).order(started_at: :desc, created_at: :desc).map do |record|
          hydrate_run(record)
        end
      end

      def pending_approvals
        all_runs.select(&:waiting_for_approval?)
      end

      def find_runs_for_subject(subject)
        ensure_active_record!

        reference = Rubot::Subject.reference(subject)
        return [] unless reference

        Rubot::RunRecord.includes(:event_records, :tool_call_records, :approval_records)
                        .where(subject_type: reference.type, subject_id: reference.id)
                        .order(started_at: :desc, created_at: :desc)
                        .map { |record| hydrate_run(record) }
      end

      def claim_run_execution(run_or_id)
        ensure_active_record!

        run_id = run_or_id.respond_to?(:id) ? run_or_id.id : run_or_id
        claimed_run = nil

        ActiveRecord::Base.transaction do
          record = Rubot::RunRecord.lock.find_by(id: run_id)
          return nil unless record
          return nil if terminal_status?(record.status)
          return nil if record.execution_claim_token.present?

          guard_subject_concurrency!(record)

          record.execution_claim_token = SecureRandom.uuid
          record.execution_claimed_at = Rubot.configuration.time_source.call
          record.save!

          claimed_run = hydrate_run(record.reload)
          claimed_run.execution_claim_token = record.execution_claim_token
          claimed_run.execution_claimed_at = record.execution_claimed_at
        end

        claimed_run
      rescue ActiveRecord::StaleObjectError => e
        raise Rubot::ConcurrencyError, e.message
      end

      def release_run_execution(run)
        ensure_active_record!
        return run unless run&.execution_claim_token

        ActiveRecord::Base.transaction do
          record = Rubot::RunRecord.lock.find_by(id: run.id)
          return run unless record
          return run unless record.execution_claim_token == run.execution_claim_token

          record.execution_claim_token = nil
          record.execution_claimed_at = nil
          record.save!
        end

        run.execution_claim_token = nil
        run.execution_claimed_at = nil
        run
      end

      def execution_claims_supported?
        true
      end

      private

      def ensure_active_record!
        raise Rubot::ExecutionError, "Active Record is not available" unless defined?(ActiveRecord::Base)
        raise Rubot::ExecutionError, "Rubot::RunRecord is not loaded" unless defined?(Rubot::RunRecord)
      end

      def assign_run_attributes(record, run)
        record.workflow_name = run.kind == :workflow ? run.name : nil
        record.agent_name = run.kind == :agent ? run.name : nil
        record.status = run.status.to_s
        record.current_step = run.current_step&.to_s
        record.subject_type = run.subject&.class&.name
        record.subject_id = run.subject&.respond_to?(:id) ? run.subject.id.to_s : nil
        record.input_payload = run.input
        record.context_payload = run.context
        record.state_payload = run.state
        record.output_payload = run.output
        record.error_payload = run.error
        record.correlation_id = run.trace_id
        record.replay_of_run_id = run.replay_of_run_id
        record.cancellation_requested_at = run.cancellation_requested_at
        record.canceled_at = run.canceled_at
        record.execution_claim_token = run.execution_claim_token
        record.execution_claimed_at = run.execution_claimed_at
        record.started_at = run.started_at
        record.completed_at = run.completed_at
      end

      def replace_events(record, run)
        record.event_records.delete_all
        run.events.each do |event|
          record.event_records.create!(
            event_type: event.type,
            step_name: event.step_name,
            payload: event.payload,
            created_at: event.timestamp,
            updated_at: event.timestamp
          )
        end
      end

      def replace_tool_calls(record, run)
        record.tool_call_records.delete_all
        run.tool_calls.each do |tool_call|
          started_at = run.started_at || Rubot.configuration.time_source.call
          completed_at = run.completed_at || started_at

          record.tool_call_records.create!(
            tool_name: tool_call[:tool_name] || tool_call["tool_name"],
            status: tool_call[:status] || tool_call["status"],
            input_payload: tool_call[:input] || tool_call["input"] || {},
            output_payload: tool_call[:output] || tool_call["output"],
            error_payload: tool_call[:error] || tool_call["error"],
            duration_ms: tool_call[:duration_ms] || tool_call["duration_ms"],
            started_at: started_at,
            completed_at: completed_at
          )
        end
      end

      def replace_approvals(record, run)
        record.approval_records.delete_all
        run.approvals.each do |approval|
          record.approval_records.create!(
            step_name: approval.step_name,
            status: approval.status.to_s,
            assigned_to_type: approval.assigned_to_type,
            assigned_to_id: approval.assigned_to_id,
            role_requirement: approval.role_requirement,
            reason: approval.reason,
            sla_due_at: approval.sla_due_at,
            expires_at: approval.expires_at,
            decision_payload: approval.decision_payload,
            decided_at: approval.decided_at
          )
        end
      end

      def hydrate_run(record)
        return unless record

        kind = record.workflow_name ? :workflow : :agent
        name = record.workflow_name || record.agent_name
        subject_reference = Rubot::Subject::Reference.new(GlobalID.new(URI::GID.build(app: GlobalID.app || "rubot", model_name: record.subject_type, model_id: record.subject_id))) if record.subject_type && record.subject_id
        subject = Rubot::Subject.resolve(subject_reference)

        Rubot::Run.restore(
          id: record.id,
          name: name,
          kind: kind,
          input: deep_symbolize(record.input_payload || {}),
          context: deep_symbolize(record.context_payload || {}),
          subject: subject,
          subject_ref: subject_reference,
          status: record.status.to_sym,
          state: deep_symbolize(record.state_payload || {}),
          output: deep_symbolize(record.output_payload),
          error: deep_symbolize(record.error_payload),
          trace_id: record.correlation_id,
          replay_of_run_id: record.replay_of_run_id,
          cancellation_requested_at: record.cancellation_requested_at,
          canceled_at: record.canceled_at,
          execution_claim_token: record.execution_claim_token,
          execution_claimed_at: record.execution_claimed_at,
          current_step: record.current_step&.to_sym,
          started_at: record.started_at,
          completed_at: record.completed_at,
          events: record.event_records.order(:created_at, :id).map do |event_record|
            Rubot::Event.new(
              type: event_record.event_type,
              step_name: event_record.step_name,
              payload: deep_symbolize(event_record.payload || {}),
              timestamp: event_record.created_at
            )
          end,
          approvals: record.approval_records.order(:created_at, :id).map do |approval_record|
            Rubot::Approval.new(
              step_name: approval_record.step_name,
              assigned_to_type: approval_record.assigned_to_type,
              assigned_to_id: approval_record.assigned_to_id,
              role_requirement: approval_record.role_requirement,
              reason: approval_record.reason,
              status: approval_record.status.to_sym,
              sla_due_at: approval_record.sla_due_at,
              expires_at: approval_record.expires_at,
              decision_payload: deep_symbolize(approval_record.decision_payload),
              decided_at: approval_record.decided_at
            )
          end,
          tool_calls: record.tool_call_records.order(:created_at, :id).map do |tool_call_record|
            {
              tool_name: tool_call_record.tool_name,
              status: tool_call_record.status,
              input: deep_symbolize(tool_call_record.input_payload || {}),
              output: deep_symbolize(tool_call_record.output_payload),
              error: deep_symbolize(tool_call_record.error_payload),
              duration_ms: tool_call_record.duration_ms
            }
          end
        )
      end

      def deep_symbolize(value)
        case value
        when Array
          value.map { |item| deep_symbolize(item) }
        when Hash
          value.each_with_object({}) do |(key, nested_value), memo|
            memo[key.respond_to?(:to_sym) ? key.to_sym : key] = deep_symbolize(nested_value)
          end
        else
          value
        end
      end

      def terminal_status?(status)
        %w[completed failed canceled].include?(status.to_s)
      end

      def guard_subject_concurrency!(record)
        return if record.subject_type.to_s.empty? || record.subject_id.to_s.empty?

        conflict = Rubot::RunRecord.lock.where(subject_type: record.subject_type, subject_id: record.subject_id)
                                   .where.not(id: record.id)
                                   .where(status: %w[queued running waiting_for_approval])
                                   .exists?
        return unless conflict

        raise Rubot::ConcurrencyError, "Another Rubot run is already active for #{record.subject_type}(#{record.subject_id})"
      end
    end
  end
end
