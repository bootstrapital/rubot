# frozen_string_literal: true

require_relative "test_helper"

class FlowLookupTool < Rubot::Tool
  input_schema do
    string :ticket_id
  end

  output_schema do
    string :ticket_id
  end

  def call(ticket_id:)
    { ticket_id: ticket_id }
  end
end

class FlowSummaryAgent < Rubot::Agent
  input_schema do
    string :ticket_id
  end

  output_schema do
    string :summary
  end

  def perform(input:, run:, context:)
    { summary: "#{input[:ticket_id]}:#{context[:channel]}" }
  end
end

class FlowWorkflow < Rubot::Workflow
  tool_step :lookup_ticket,
            tool: FlowLookupTool,
            input: from_input(:ticket_id)

  agent_step :summarize_ticket,
             agent: FlowSummaryAgent,
             input: merge(from_state(:lookup_ticket), from_context(:channel))

  approval_step :manager_review, role: "ops_manager"
  output :summarize_ticket
end

class FlowOperation < Rubot::Operation
  workflow :default, FlowWorkflow, default: true
  trigger :manual
  trigger :expedite, workflow: :default
  entrypoint :review, workflow: :default
  entrypoint :expedited_review, trigger: :expedite
end

class FlowVisualizationTest < Minitest::Test
  def test_workflow_flow_graph_captures_step_sequence_and_safe_data_edges
    graph = FlowWorkflow.flow_graph.to_h

    node_labels = graph[:nodes].map { |node| node[:label] }
    edge_pairs = graph[:edges].map { |edge| [edge[:from], edge[:to], edge[:kind], edge[:label]] }

    assert_includes node_labels, "lookup_ticket (tool_step)"
    assert_includes node_labels, "summarize_ticket (agent_step)"
    assert_includes node_labels, "manager_review (approval_step)"
    assert_includes edge_pairs, ["FlowWorkflow_input", "FlowWorkflow_lookup_ticket", :sequence, nil]
    assert_includes edge_pairs, ["FlowWorkflow_lookup_ticket", "FlowWorkflow_summarize_ticket", :data_flow, "lookup_ticket"]
    assert_includes edge_pairs, ["FlowWorkflow_context", "FlowWorkflow_summarize_ticket", :data_flow, "channel"]
  end

  def test_operation_flow_mermaid_includes_workflows_triggers_and_entrypoints
    mermaid = FlowOperation.flow_mermaid

    assert_includes mermaid, "entrypoint: review"
    assert_includes mermaid, "entrypoint: expedited_review"
    assert_includes mermaid, "trigger: expedite"
    assert_includes mermaid, "workflow: default"
    assert_includes mermaid, "lookup_ticket (tool_step)"
    assert_includes mermaid, "summarize_ticket (agent_step)"
  end
end
