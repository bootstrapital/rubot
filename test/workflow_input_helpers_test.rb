# frozen_string_literal: true

require_relative "test_helper"

class WorkflowInputCaptureTool < Rubot::Tool
  input_schema do
    string :ticket_id, required: false
    string :channel, required: false
    string :assignee, required: false
    string :note, required: false
  end

  output_schema do
    string :ticket_id, required: false
    string :channel, required: false
    string :assignee, required: false
    string :note, required: false
  end

  def call(ticket_id: nil, channel: nil, assignee: nil, note: nil)
    {
      ticket_id: ticket_id,
      channel: channel,
      assignee: assignee,
      note: note
    }.compact
  end
end

class WorkflowInputSummaryAgent < Rubot::Agent
  input_schema do
    string :ticket_id
    string :channel
    string :assignee
  end

  output_schema do
    string :summary
  end

  def perform(input:, run:, context:)
    { summary: "#{input[:ticket_id]}:#{input[:channel]}:#{input[:assignee]}:#{context[:note]}" }
  end
end

class WorkflowInputHelpersWorkflow < Rubot::Workflow
  tool_step :capture_ticket,
            tool: WorkflowInputCaptureTool,
            input: from_input(:ticket_id)

  tool_step :enrich_ticket,
            tool: WorkflowInputCaptureTool,
            input: merge(from_state(:capture_ticket), from_context(:channel), { assignee: "ops" })

  tool_step :slice_ticket,
            tool: WorkflowInputCaptureTool,
            input: merge(slice(from_state(:enrich_ticket), :ticket_id, :channel), { note: "sliced" })

  agent_step :summarize_ticket,
             agent: WorkflowInputSummaryAgent,
             input: from_state(:enrich_ticket)

  tool_step :legacy_proc,
            tool: WorkflowInputCaptureTool,
            input: ->(_input, state, _context) { { note: state.fetch(:slice_ticket).fetch(:note) } }
end

class WorkflowInputHelpersTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_helpers_map_input_state_and_context_without_raw_lambdas
    run = Rubot.run(
      WorkflowInputHelpersWorkflow,
      input: { ticket_id: "t_123" },
      context: { channel: "email", note: "context-note" }
    )

    assert_equal :completed, run.status
    assert_equal({ ticket_id: "t_123" }, run.state[:capture_ticket])
    assert_equal({ ticket_id: "t_123", channel: "email", assignee: "ops" }, run.state[:enrich_ticket])
    assert_equal({ ticket_id: "t_123", channel: "email", note: "sliced" }, run.state[:slice_ticket])
    assert_equal "t_123:email:ops:context-note", run.state[:summarize_ticket][:summary]
    assert_equal({ note: "sliced" }, run.state[:legacy_proc])
  end

  def test_input_mapping_helpers_are_inspectable
    mapping = WorkflowInputHelpersWorkflow.merge(
      WorkflowInputHelpersWorkflow.from_input(:ticket_id),
      WorkflowInputHelpersWorkflow.from_context(:channel)
    )

    assert_includes mapping.inspect, "Rubot::Workflow::InputMapping"
    assert_includes mapping.inspect, "merge"
    assert_includes mapping.inspect, "from_input"
  end

  def test_merge_helper_fails_gracefully_with_non_hash_values
    mapping = WorkflowInputHelpersWorkflow.merge(
      ->(_input, _state, _context) { "not-a-hash" }
    )

    error = assert_raises(Rubot::ValidationError) do
      mapping.call({}, {}, {})
    end
    assert_includes error.message, "merge sources must resolve to mappings"
  end

  def test_slice_helper_fails_gracefully_with_non_hash_values
    mapping = WorkflowInputHelpersWorkflow.slice(
      ->(_input, _state, _context) { "not-a-hash" },
      :key
    )

    error = assert_raises(Rubot::ValidationError) do
      mapping.call({}, {}, {})
    end
    assert_includes error.message, "slice source must resolve to a mapping"
  end

  def test_nested_merge_and_slice_composition
    state = { step_a: { a: 1, b: 2 } }
    context = { c: 3 }
    
    mapping = WorkflowInputHelpersWorkflow.merge(
      WorkflowInputHelpersWorkflow.slice(WorkflowInputHelpersWorkflow.from_state(:step_a), :a),
      WorkflowInputHelpersWorkflow.from_context(:c)
    )

    result = mapping.call({}, state, context)
    assert_equal({ a: 1, c: 3 }, result)
  end
end
