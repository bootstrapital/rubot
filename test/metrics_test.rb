# frozen_string_literal: true

require_relative "test_helper"

class MetricsTest < Minitest::Test
  def test_aggregator_summarizes_run_tool_approval_and_model_usage_metrics
    now = Time.utc(2026, 3, 24, 12, 0, 0)
    Rubot.configure { |config| config.time_source = -> { now } }

    run = Rubot::Run.new(name: "MetricsWorkflow", kind: :workflow, input: {}, persist: false)
    run.start!
    run.add_event(Rubot::Event.new(type: "approval.requested", step_name: "review", timestamp: now))
    approval = Rubot::Approval.new(step_name: "review")
    run.add_approval(approval)
    approval.approve!({})
    run.add_tool_call({ tool_name: "ExampleTool", status: "completed" })
    run.add_event(
      Rubot::Event.new(
        type: "model.response.received",
        payload: { usage: { total_tokens: 42, total_cost: 0.123456 } },
        timestamp: now
      )
    )
    run.complete!({})

    summary = Rubot::Metrics::Aggregator.new([run]).summary

    assert_equal 1, summary[:total_runs]
    assert_equal 42, summary[:total_model_tokens]
    assert_equal 0.123456, summary[:total_model_cost]
    assert_equal 1.0, summary[:tool_success_rate]
  end
end
