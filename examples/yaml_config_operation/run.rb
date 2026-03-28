# frozen_string_literal: true

require "json"
require_relative "operation"

agent = YamlConfigOperationExample::ReviewAccountAgent

puts JSON.pretty_generate(
  agent_config: {
    instructions: agent.instructions,
    model: agent.model,
    description: agent.description,
    tags: agent.tags,
    metadata: agent.metadata
  }
)

run = Rubot.run(
  YamlConfigOperationExample::Operation.runnable,
  input: { account_id: "acct_129" },
  context: { default_action: "continue" }
)

puts JSON.pretty_generate(run.to_h)
