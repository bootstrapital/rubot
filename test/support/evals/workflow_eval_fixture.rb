# frozen_string_literal: true

class RakeEvalEchoTool < Rubot::Tool
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

class RakeEvalWorkflow < Rubot::Workflow
  tool_step :echo, tool: RakeEvalEchoTool
end

class WorkflowEvalFixture < Rubot::Eval
  target RakeEvalWorkflow

  fixture :matching, input: { value: "hello" }, expected: { echo: { value: "hello" } }
  assert_threshold :output_match, equals: 1.0
end
