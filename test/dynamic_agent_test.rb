# frozen_string_literal: true

require_relative "test_helper"

class TierOneTool < Rubot::Tool
  input_schema do
    string :value
  end

  output_schema do
    string :value
  end

  def call(value:)
    { value: "tier1:#{value}" }
  end
end

class TierTwoTool < Rubot::Tool
  input_schema do
    string :value
  end

  output_schema do
    string :value
  end

  def call(value:)
    { value: "tier2:#{value}" }
  end
end

class DynamicAgentProvider
  attr_reader :requests

  def initialize(response)
    @response = response
    @requests = []
  end

  def complete(messages:, tools:, output_schema:, model:)
    @requests << { messages:, tools:, output_schema:, model: }

    Rubot::Providers::Result.new(
      provider: "test",
      model: model,
      content: "",
      output: @response,
      tool_calls: [],
      usage: {},
      finish_reason: "stop"
    )
  end
end

class DynamicRoutingAgent < Rubot::Agent
  instructions do |runtime|
    "Handle #{runtime.context[:tenant]} for #{runtime.input[:ticket_id]}"
  end

  model ->(runtime) { runtime.context[:premium] ? "gpt-premium" : "gpt-standard" }
  tools ->(runtime) { runtime.context[:premium] ? [TierOneTool, TierTwoTool] : [TierOneTool] }

  input_schema do
    string :ticket_id
  end

  output_schema do
    string :summary
  end
end

class DynamicAgentTest < Minitest::Test
  def setup
    @provider = DynamicAgentProvider.new(summary: "resolved")

    Rubot.configure do |config|
      config.provider = @provider
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_agent_resolves_model_tools_and_instructions_from_runtime_context
    run = Rubot.run(
      DynamicRoutingAgent,
      input: { ticket_id: "t_123" },
      context: { tenant: "acme", premium: true }
    )

    assert_equal :completed, run.status

    request = @provider.requests.last
    assert_equal "gpt-premium", request[:model]
    assert_equal ["TierOneTool", "TierTwoTool"], request[:tools].map(&:name).map { |name| name.split("::").last }
    assert_equal "Handle acme for t_123", request[:messages].first[:content]

    event = run.events.find { |item| item.type == "agent.configuration.resolved" }
    refute_nil event
    assert_equal "gpt-premium", event.payload[:model]
    assert_equal ["TierOneTool", "TierTwoTool"], event.payload[:tools].map { |name| name.split("::").last }
  end

  def test_agent_can_resolve_different_configuration_for_other_contexts
    Rubot.run(
      DynamicRoutingAgent,
      input: { ticket_id: "t_456" },
      context: { tenant: "basic", premium: false }
    )

    request = @provider.requests.last
    assert_equal "gpt-standard", request[:model]
    assert_equal ["TierOneTool"], request[:tools].map(&:name).map { |name| name.split("::").last }
    assert_equal "Handle basic for t_456", request[:messages].first[:content]
  end
end
