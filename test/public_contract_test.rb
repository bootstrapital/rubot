# frozen_string_literal: true

require_relative "test_helper"

class PublicContractTest < Minitest::Test
  def test_top_level_rubot_runtime_entrypoints_exist
    assert_respond_to Rubot, :configure
    assert_respond_to Rubot, :run
    assert_respond_to Rubot, :run_for
    assert_respond_to Rubot, :enqueue
    assert_respond_to Rubot, :enqueue_for
    assert_respond_to Rubot, :resume_later
    assert_respond_to Rubot, :replay
  end

  def test_agent_workflow_and_operation_surface_includes_recent_v0_2_helpers
    assert_respond_to Rubot::Agent, :config_file
    assert_respond_to Rubot::Agent, :tags
    assert_respond_to Rubot::Agent, :metadata

    assert_respond_to Rubot::Workflow, :from_input
    assert_respond_to Rubot::Workflow, :from_state
    assert_respond_to Rubot::Workflow, :from_context
    assert_respond_to Rubot::Workflow, :slice
    assert_respond_to Rubot::Workflow, :merge
    assert_respond_to Rubot::Workflow, :output
    assert_respond_to Rubot::Workflow, :flow_graph
    assert_respond_to Rubot::Workflow, :flow_mermaid

    assert_respond_to Rubot::Operation, :entrypoint
    assert_respond_to Rubot::Operation, :entrypoints
    assert_respond_to Rubot::Operation, :flow_graph
    assert_respond_to Rubot::Operation, :flow_mermaid
  end
end
