# frozen_string_literal: true

require_relative "test_helper"
require "rake"
require "open3"

class EvalEchoTool < Rubot::Tool
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

class EvalWorkflow < Rubot::Workflow
  tool_step :echo, tool: EvalEchoTool
end

class EvalOperation < Rubot::Operation
  workflow EvalWorkflow
end

class EvalProviderTransport
  def complete(_request)
    {
      output: {
        queue: "ops",
        summary: "ok"
      },
      model: "gpt-eval",
      provider: "ruby_llm"
    }
  end
end

class EvalProviderAgent < Rubot::Agent
  instructions { "Respond with a queue and summary." }
  model "gpt-eval"

  input_schema do
    string :ticket_id
  end

  output_schema do
    string :queue
    string :summary
  end
end

class WorkflowEval < Rubot::Eval
  target EvalWorkflow

  fixture :matching, input: { value: "hello" }, expected: { echo: { value: "hello" } }
  fixture :dynamic do
    { input: { value: "dynamic" }, expected: { echo: { value: "dynamic" } }, metadata: { source: "block" } }
  end

  score :output_match do |result|
    result.output == result.expected
  end

  assert_threshold :output_match, equals: 1.0
end

class FailingWorkflowEval < Rubot::Eval
  target EvalWorkflow

  fixture :mismatch, input: { value: "hello" }, expected: { echo: { value: "wrong" } }
  assert_threshold :output_match, equals: 1.0
end

class OperationEval < Rubot::Eval
  target EvalOperation

  fixture :launches_operation, input: { value: "through_operation" }, expected: { echo: { value: "through_operation" } }
  assert_threshold :output_match, equals: 1.0
end

class ProviderAgentEval < Rubot::Eval
  target EvalProviderAgent

  fixture :provider_case, input: { ticket_id: "t_123" }, expected: { queue: "ops", summary: "ok" }
  assert_threshold :output_match, equals: 1.0
end

class EvalTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
      config.provider = Rubot::Providers::RubyLLM.new(transport: EvalProviderTransport.new, provider_name: "openai")
      config.default_model = "gpt-eval"
      config.default_provider_name = "openai"
    end
  end

  def test_eval_runs_fixtures_and_applies_thresholds
    report = WorkflowEval.run

    assert report.passed?
    assert_equal 2, report.total_count
    assert_equal 1.0, report.results.first.scores[:output_match]
    assert_equal({ source: "block" }, report.results.last.metadata)
    assert report.to_s.include?("WorkflowEval: PASS")
  end

  def test_eval_uses_default_output_match_score_when_no_custom_score_defined
    report = OperationEval.run

    assert report.passed?
    assert_equal :completed, report.results.first.run.status
  end

  def test_eval_can_run_provider_backed_agents
    report = ProviderAgentEval.run

    assert report.passed?
    assert_equal "ops", report.results.first.run.output[:queue]
  end

  def test_eval_reports_failures
    report = FailingWorkflowEval.run

    refute report.passed?
    assert_includes report.results.first.failures.first, "output_match was 0.0"
  end

  def test_rubot_can_resolve_eval_by_name
    report = Rubot.run_eval("WorkflowEval")

    assert_instance_of Rubot::Eval::Report, report
    assert report.passed?
  end

  def test_rake_task_exits_successfully_for_passing_eval
    out, err, status = Open3.capture3("rake", "rubot:eval[WorkflowEvalFixture]")

    assert status.success?, "#{out}\n#{err}"
    assert_includes out, "WorkflowEvalFixture: PASS"
  end
end
