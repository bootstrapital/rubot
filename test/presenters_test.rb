# frozen_string_literal: true

require_relative "test_helper"

class PresenterTool < Rubot::Tool
  input_schema do
    string :value
  end

  output_schema do
    float :confidence
    array :warnings, of: :string
  end

  def call(value:)
    { confidence: 0.82, warnings: ["double-check #{value}"] }
  end
end

class PresenterWorkflow < Rubot::Workflow
  tool_step :inspect_value,
            tool: PresenterTool,
            input: ->(input, _state, _context) { { value: input[:value] } }
end

class PresentersTest < Minitest::Test
  def test_run_presenter_groups_step_results_and_tool_calls
    run = Rubot.run(PresenterWorkflow, input: { value: "abc" })
    presenter = Rubot::Presenters::RunPresenter.new(run)

    step = presenter.step_groups.first

    assert_equal "inspect_value", step[:name]
    assert_equal :completed, step[:status]
    assert_equal 0.82, step[:confidence]
    assert_equal ["double-check abc"], step[:warnings]
    assert_equal 1, step[:tool_calls].length
  end

  def test_tool_call_presenter_exposes_badges_and_step_name
    run = Rubot.run(PresenterWorkflow, input: { value: "abc" })
    presenter = Rubot::Presenters::RunPresenter.new(run)
    tool_call = presenter.tool_calls.first

    assert_equal "PresenterTool", tool_call.short_name
    assert_equal "inspect_value", tool_call.step_name
    assert_equal 0.82, tool_call.confidence
    assert_equal ["double-check abc"], tool_call.warnings
  end
end
