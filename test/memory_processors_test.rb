# frozen_string_literal: true

require_relative "test_helper"

class MemoryProcessorProvider
  attr_reader :requests

  def initialize(responses)
    @responses = responses
    @requests = []
  end

  def complete(messages:, tools:, output_schema:, model:)
    @requests << { messages: messages, tools: tools, output_schema: output_schema, model: model }
    response = @responses.is_a?(Array) ? @responses.shift : @responses

    Rubot::Providers::Result.new(
      provider: "test",
      model: model || "memory-model",
      content: response[:content].to_s,
      output: response[:output],
      tool_calls: response[:tool_calls] || [],
      usage: {},
      finish_reason: "stop"
    )
  end
end

class MemoryEchoTool < Rubot::Tool
  input_schema do
    string :value
  end

  output_schema do
    string :value
  end

  def call(value:)
    { value: "tool:#{value}" }
  end
end

class MemoryFilteredAgent < Rubot::Agent
  tools MemoryEchoTool

  memory do
    processor Rubot::Memory::Processors::ToolCallFilter
  end

  input_schema do
    string :value
  end

  output_schema do
    string :summary
  end
end

class MemoryLimitedAgent < Rubot::Agent
  memory do
    processor Rubot::Memory::Processors::TokenLimiter, max_tokens: 18
  end

  input_schema do
    string :value
  end

  output_schema do
    string :summary
  end
end

class MemoryOperation < Rubot::Operation
  memory do
    processor Rubot::Memory::Processors::TokenLimiter, max_tokens: 18
  end

  agent do
    input_schema do
      string :value
    end

    output_schema do
      string :summary
    end
  end

  trigger :manual
end

class MemoryProcessorsTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_tool_call_filter_removes_tool_messages_from_model_context_only
    provider = MemoryProcessorProvider.new(
      [
        {
          content: "need tool",
          tool_calls: [{ id: "call_1", name: "MemoryEchoTool", arguments: { value: "abc" } }]
        },
        {
          output: { summary: "done" }
        }
      ]
    )

    Rubot.configure { |config| config.provider = provider }

    run = Rubot.run(MemoryFilteredAgent, input: { value: "abc" })

    assert_equal :completed, run.status
    assert_equal 1, run.tool_calls.length

    second_request = provider.requests.last
    refute second_request[:messages].any? { |message| message[:role].to_s == "tool" }
    refute second_request[:messages].any? { |message| message.key?(:tool_calls) }

    context_event = run.events.find { |event| event.type == "memory.context.built" && event.payload[:turn] == 2 }
    refute_nil context_event
    assert_equal "Rubot::Memory::Processors::ToolCallFilter", context_event.payload[:processors].first[:processor]
  end

  def test_token_limiter_drops_oldest_messages_from_context
    provider = MemoryProcessorProvider.new(output: { summary: "trimmed" })
    Rubot.configure { |config| config.provider = provider }

    run = Rubot::Run.new(name: MemoryLimitedAgent.name, kind: :agent, input: { value: "abcdefghijklmnopqrstuvwxyz" }, persist: false)
    agent = MemoryLimitedAgent.new
    history = [
      { role: :system, content: "system prompt" },
      { role: :user, content: "first #{'x' * 40}" },
      { role: :assistant, content: "second #{'y' * 40}" },
      { role: :user, content: "third #{'z' * 40}" }
    ]

    result = agent.send(
      :build_model_context,
      messages: history,
      run: run,
      turn: 1,
      input: { value: "abcdefghijklmnopqrstuvwxyz" },
      context: {}
    )

    assert_equal "system", result[:messages].first[:role].to_s
    assert_operator result[:messages].length, :<, history.length
    assert_operator result[:estimated_tokens], :<=, 18
  end

  def test_operation_memory_config_applies_to_inline_agent
    provider = MemoryProcessorProvider.new(output: { summary: "from operation" })
    Rubot.configure { |config| config.provider = provider }

    run = MemoryOperation.launch(payload: { value: "abc" })

    assert_equal :completed, run.status
    context_event = run.events.find { |event| event.type == "memory.context.built" }
    refute_nil context_event
    assert_equal "Rubot::Memory::Processors::TokenLimiter", context_event.payload[:processors].first[:processor]
  end
end
