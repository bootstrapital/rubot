# frozen_string_literal: true

require_relative "../../lib/rubot"
require_relative "tools/load_account_snapshot_tool"
require_relative "agents/review_account_agent"
require_relative "workflow"

module YamlConfigOperationExample
  class Operation < Rubot::Operation
    tool :load_account_snapshot, YamlConfigOperationExample::LoadAccountSnapshotTool
    agent :review_account, YamlConfigOperationExample::ReviewAccountAgent
    workflow :review, YamlConfigOperationExample::Workflow, default: true

    entrypoint :review_account, workflow: :review
  end
end
