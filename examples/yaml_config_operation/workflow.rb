# frozen_string_literal: true

module YamlConfigOperationExample
  class Workflow < Rubot::Workflow
    tool_step :load_account_snapshot,
              tool: LoadAccountSnapshotTool,
              input: from_input(:account_id)

    agent_step :review_account,
               agent: ReviewAccountAgent,
               input: from_state(:load_account_snapshot)

    step :finalize

    def finalize
      run.state[:finalize] = {
        review: run.state.fetch(:review_account),
        configured_model: ReviewAccountAgent.model
      }
    end

    output :finalize
  end
end
