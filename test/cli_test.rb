# frozen_string_literal: true

require_relative "test_helper"
require "rubot/cli"

class CliEvalEchoTool < Rubot::Tool
  input_schema { string :value }
  output_schema { string :value }
  def call(value:)
    { value: value }
  end
end

class CliEvalWorkflow < Rubot::Workflow
  tool_step :echo, tool: CliEvalEchoTool
end

class CliWorkflowEval < Rubot::Eval
  target CliEvalWorkflow
  fixture :matching, input: { value: "hello" }, expected: { echo: { value: "hello" } }
end

class CliTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_help_command
    out, _err = capture_io do
      begin
        Rubot::CLI.start(["help"])
      rescue SystemExit
      end
    end
    assert_includes out, "Usage: rubot [command] [options]"
    assert_includes out, "eval [target]"
  end

  def test_eval_command_runs_evals
    # We need to make sure CliWorkflowEval is discoverable
    out, _err = capture_io do
      begin
        Rubot::CLI.start(["eval", "CliWorkflowEval"])
      rescue SystemExit => e
        assert_equal 0, e.status
      end
    end
    assert_includes out, "CliWorkflowEval: PASS"
  end

  def test_eval_command_json_format
    out, _err = capture_io do
      begin
        Rubot::CLI.start(["eval", "CliWorkflowEval", "--format", "json"])
      rescue SystemExit => e
        assert_equal 0, e.status
      end
    end
    
    json = JSON.parse(out)
    assert_kind_of Array, json
    assert_equal "CliWorkflowEval", json.first["eval_class"]
    assert json.first["passed"]
  end

  def test_eval_command_fails_on_failure
    # Define a failing eval
    eval_class = Class.new(Rubot::Eval) do
      target CliEvalWorkflow
      fixture :mismatch, input: { value: "hello" }, expected: { echo: { value: "wrong" } }
    end
    Object.const_set(:CliFailingEval, eval_class)

    out, _err = capture_io do
      begin
        Rubot::CLI.start(["eval", "CliFailingEval"])
      rescue SystemExit => e
        assert_equal 1, e.status
      end
    end
    assert_includes out, "CliFailingEval: FAIL"
  ensure
    Object.send(:remove_const, :CliFailingEval) if Object.const_defined?(:CliFailingEval)
  end
end
