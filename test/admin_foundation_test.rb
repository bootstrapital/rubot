# frozen_string_literal: true

require_relative "test_helper"

class AdminFoundationTest < Minitest::Test
  def test_run_presenter_exposes_admin_json_contract
    run = Rubot::Run.new(name: "DemoAgent", kind: :agent, input: { value: "abc" }, persist: false)
    run.start!
    run.complete!({ summary: "done" })

    payload = Rubot::Presenters::RunPresenter.new(run).as_admin_json

    assert_equal run.id, payload[:id]
    assert_equal "DemoAgent", payload[:name]
    assert_equal "DemoAgent", payload[:runnable_name]
    assert_equal :agent, payload[:kind]
    assert_equal :completed, payload[:status]
    assert_equal({ summary: "done" }, payload[:output])
    assert payload.key?(:events)
    assert payload.key?(:tool_calls)
  end

  def test_approval_presenter_exposes_admin_json_contract
    run = Rubot::Run.new(name: "DemoWorkflow", kind: :workflow, input: {}, persist: false)
    approval = Rubot::Approval.new(step_name: "review", role_requirement: "ops")

    payload = Rubot::Presenters::ApprovalPresenter.new(run, approval).as_admin_json

    assert_equal run.id, payload[:run_id]
    assert_equal "review", payload[:step_name]
    assert_equal "ops", payload[:role]
    assert_equal "ops", payload[:role_requirement]
    assert_equal "pending", payload[:status]
  end
end
