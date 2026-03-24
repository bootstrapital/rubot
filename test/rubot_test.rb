# frozen_string_literal: true

require_relative "test_helper"

class EchoTool < Rubot::Tool
  input_schema do
    string :value
  end

  output_schema do
    string :value
  end

  def call(value:)
    { value: value }
  end
end

class SummarizeAgent < Rubot::Agent
  input_schema do
    string :value
  end

  output_schema do
    string :summary
  end

  def perform(input:, run:, context:)
    { summary: "#{context[:prefix]}#{input[:value]}" }
  end
end

class DemoWorkflow < Rubot::Workflow
  tool_step :echo_value,
            tool: EchoTool,
            input: ->(input, _state, _context) { { value: input[:value] } }

  agent_step :summarize_value,
             agent: SummarizeAgent,
             input: ->(_input, state, _context) { state.fetch(:echo_value) }

  approval_step :review, role: "reviewer"

  step :finalize

  def finalize
    run.state[:finalize] = {
      approved_by: run.approvals.last.decision_payload[:approved_by],
      summary: run.state[:summarize_value][:summary]
    }
  end
end

class RubotTest < Minitest::Test
  def test_workflow_pause_and_resume
    run = Rubot.run(DemoWorkflow, input: { value: "abc" }, context: { prefix: "seen:" })

    assert_equal :waiting_for_approval, run.status
    assert_equal "seen:abc", run.state[:summarize_value][:summary]

    run.approve!(approved_by: "ops@example.com")
    Rubot::Executor.new.resume(DemoWorkflow, run)

    assert_equal :completed, run.status
    assert_equal "ops@example.com", run.state[:finalize][:approved_by]
    assert_equal "seen:abc", run.output[:finalize][:summary]
  end

  def test_schema_validation_raises_for_missing_required_fields
    assert_raises(Rubot::ValidationError) do
      Rubot.run(DemoWorkflow, input: {}, context: { prefix: "seen:" })
    end
  end
end
