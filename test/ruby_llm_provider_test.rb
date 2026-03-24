# frozen_string_literal: true

require_relative "test_helper"

class ProviderLookupTool < Rubot::Tool
  description "Lookup a ticket."

  input_schema do
    string :ticket_id
  end

  output_schema do
    string :ticket_id
    string :status
  end

  def call(ticket_id:)
    { ticket_id: ticket_id, status: "open" }
  end
end

class ProviderBackedAgent < Rubot::Agent
  instructions do
    "Review the payload and emit a routing decision."
  end

  tools ProviderLookupTool
  model "gpt-test"

  input_schema do
    string :ticket_id
  end

  output_schema do
    string :queue
    string :summary
  end
end

class FakeRubyLLMTransport
  attr_reader :requests

  def initialize(response)
    @response = response
    @requests = []
  end

  def complete(request)
    @requests << request
    @response.is_a?(Array) ? @response.shift : @response
  end
end

class RubyLLMProviderTest < Minitest::Test
  def setup
    @transport = FakeRubyLLMTransport.new(
      output: {
        queue: "finance_support",
        summary: "Route the billing ticket"
      },
      usage: {
        prompt_tokens: 12,
        completion_tokens: 8,
        total_tokens: 20
      },
      finish_reason: "stop",
      model: "gpt-test",
      provider: "ruby_llm"
    )

    Rubot.configure do |config|
      config.provider = Rubot::Providers::RubyLLM.new(transport: @transport, provider_name: "openai")
      config.default_model = "gpt-default"
      config.default_provider_name = "openai"
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_provider_normalizes_request_and_response
    transport = FakeRubyLLMTransport.new(
      output: {
        queue: "finance_support",
        summary: "Route the billing ticket"
      },
      tool_calls: [
        { name: "ProviderLookupTool", arguments: { ticket_id: "t_123" } }
      ],
      usage: {
        prompt_tokens: 12,
        completion_tokens: 8,
        total_tokens: 20,
        prompt_cost: 0.001,
        completion_cost: 0.002,
        cost: 0.003,
        currency: "USD"
      },
      finish_reason: "stop",
      model: "gpt-test",
      provider: "ruby_llm"
    )
    provider = Rubot::Providers::RubyLLM.new(transport: transport, provider_name: "openai")

    result = provider.complete(
      messages: [
        { role: :system, content: "You are helpful." },
        { role: :user, content: "{\"ticket_id\":\"t_123\"}" }
      ],
      tools: [ProviderLookupTool],
      output_schema: ProviderBackedAgent.output_schema,
      temperature: 0.2
    )

    request = transport.requests.last

    assert_equal "gpt-default", request[:model]
    assert_equal "openai", request[:provider]
    assert_equal "system", request[:messages][0][:role]
    assert_equal "ProviderLookupTool", request[:tools][0][:name]
    assert_equal ["queue", "summary"], request[:normalized_output_schema][:required].map(&:to_s)
    assert_equal 12, result.usage[:input_tokens]
    assert_equal 8, result.usage[:output_tokens]
    assert_equal 0.001, result.usage[:input_cost]
    assert_equal 0.002, result.usage[:output_cost]
    assert_equal 0.003, result.usage[:total_cost]
    assert_equal "USD", result.usage[:currency]
    assert_equal "finance_support", result.output[:queue]
  end

  def test_agent_uses_configured_provider_when_perform_is_not_overridden
    run = Rubot.run(ProviderBackedAgent, input: { ticket_id: "t_123" }, context: { source: "test" })

    assert_equal :completed, run.status
    assert_equal "finance_support", run.output[:queue]
    assert_equal "Route the billing ticket", run.output[:summary]

    response_event = run.events.find { |event| event.type == "model.response.received" }
    refute_nil response_event
    assert_equal "ruby_llm", response_event.payload[:provider]
    assert_equal "gpt-test", response_event.payload[:model]
    assert_equal "stop", response_event.payload[:finish_reason]
    assert_equal 12, response_event.payload[:usage][:input_tokens]
    assert_equal 20, response_event.payload[:usage][:total_tokens]

    request = @transport.requests.last
    assert_equal "gpt-test", request[:model]
    assert_equal "Review the payload and emit a routing decision.", request[:messages][0][:content]
  end

  def test_agent_can_execute_provider_requested_tools_before_final_response
    transport = FakeRubyLLMTransport.new(
      [
        {
          content: "Need ticket details first.",
          tool_calls: [
            {
              id: "call_1",
              name: "ProviderLookupTool",
              arguments: { ticket_id: "t_123" }
            }
          ],
          model: "gpt-test",
          provider: "ruby_llm"
        },
        {
          output: {
            queue: "finance_support",
            summary: "Billing issue confirmed from tool context"
          },
          model: "gpt-test",
          provider: "ruby_llm"
        }
      ]
    )

    Rubot.configure do |config|
      config.provider = Rubot::Providers::RubyLLM.new(transport: transport, provider_name: "openai")
      config.default_model = "gpt-default"
      config.default_provider_name = "openai"
      config.store = Rubot::Stores::MemoryStore.new
      config.agent_max_turns = 4
    end

    run = Rubot.run(ProviderBackedAgent, input: { ticket_id: "t_123" })

    assert_equal :completed, run.status
    assert_equal "finance_support", run.output[:queue]
    assert_equal 1, run.tool_calls.length
    assert_equal "ProviderLookupTool", run.tool_calls.first[:tool_name]

    second_request = transport.requests.last
    tool_message = second_request[:messages].find { |message| message[:role] == "tool" }
    refute_nil tool_message
    assert_equal "ProviderLookupTool", tool_message[:name]
    assert_includes tool_message[:content], "\"status\":\"open\""

    assert_equal 2, run.events.count { |event| event.type == "model.response.received" }
    assert_equal 2, run.events.count { |event| event.type == "agent.tool_loop.iteration" }
  end

  def test_provider_raises_helpful_error_for_invalid_structured_output
    transport = FakeRubyLLMTransport.new(
      output: {
        queue: "finance_support"
      },
      model: "gpt-test",
      provider: "ruby_llm"
    )
    provider = Rubot::Providers::RubyLLM.new(transport: transport, provider_name: "openai")

    error = assert_raises(Rubot::ValidationError) do
      provider.complete(
        messages: [{ role: :user, content: "{\"ticket_id\":\"t_123\"}" }],
        output_schema: ProviderBackedAgent.output_schema
      )
    end

    assert_includes error.message, "Model response did not satisfy output schema"
    assert_includes error.message, "summary"
  end
end
