# frozen_string_literal: true

require_relative "test_helper"

class ApprovalWorkflow < Rubot::Workflow
  approval_step :review,
                role: "ops_manager",
                reason: "Needs review",
                assigned_to: ->(_input, _state, context) { context[:assignee] },
                sla_seconds: 60,
                expires_in: 120
end

class ApprovalTest < Minitest::Test
  def setup
    @now = Time.utc(2026, 3, 24, 12, 0, 0)
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
      config.time_source = -> { @now }
    end
  end

  def test_workflow_creates_assigned_approval_with_sla_metadata
    run = Rubot.run(ApprovalWorkflow, input: {}, context: { assignee: "ops@example.com" })
    approval = run.approvals.first

    assert_equal :waiting_for_approval, run.status
    assert_equal "ops_manager", approval.role
    assert_equal "ops_manager", approval.role_requirement
    assert_equal({ type: "String", id: "ops@example.com" }, approval.assigned_to)
    assert_equal "String", approval.assigned_to_type
    assert_equal "ops@example.com", approval.assigned_to_id
    assert_equal @now + 60, approval.sla_due_at
    assert_equal @now + 120, approval.expires_at
  end

  def test_run_emits_overdue_and_expired_events
    run = Rubot.run(ApprovalWorkflow, input: {}, context: { assignee: "ops@example.com" })

    run.check_approval_slas!(time: @now + 61)
    assert_includes run.events.map(&:type), "approval.overdue"

    run.check_approval_slas!(time: @now + 121)
    assert_equal :failed, run.status
    assert_equal :expired, run.approvals.first.status
    assert_includes run.events.map(&:type), "approval.expired"
  end

  def test_request_changes_is_distinct_from_rejection
    run = Rubot.run(ApprovalWorkflow, input: {}, context: { assignee: "ops@example.com" })

    run.request_changes!(approved_by: "ops@example.com", note: "Needs edits")

    assert_equal :failed, run.status
    assert_equal :changes_requested, run.approvals.first.status
    assert_equal "changes_requested", run.error[:type]
  end
end
