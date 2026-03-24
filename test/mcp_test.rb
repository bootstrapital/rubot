# frozen_string_literal: true

require_relative "test_helper"

class FakeMCPClient < Rubot::MCP::Client
  attr_reader :calls

  def initialize
    @calls = []
  end

  def list_tools
    [
      {
        name: "lookup_ticket",
        description: "Lookup a support ticket from a remote MCP server.",
        input_schema: {
          type: "object",
          properties: {
            ticket_id: { type: "string" }
          },
          required: ["ticket_id"]
        },
        output_schema: {
          type: "object",
          properties: {
            ticket_id: { type: "string" },
            status: { type: "string" }
          },
          required: ["ticket_id", "status"]
        }
      }
    ]
  end

  def call_tool(name, arguments = {})
    @calls << { name:, arguments: }
    { ticket_id: arguments[:ticket_id], status: "open" }
  end
end

class MCPProvider
  attr_reader :requests

  def initialize(responses)
    @responses = responses
    @requests = []
  end

  def complete(messages:, tools:, output_schema:, model:)
    @requests << { messages:, tools:, output_schema:, model: }
    response = @responses.is_a?(Array) ? @responses.shift : @responses

    Rubot::Providers::Result.new(
      provider: "test",
      model: model || "mcp-model",
      content: response[:content].to_s,
      output: response[:output],
      tool_calls: response[:tool_calls] || [],
      usage: {},
      finish_reason: "stop"
    )
  end
end

class MCPToolAgent < Rubot::Agent
  input_schema do
    string :ticket_id
  end

  output_schema do
    string :summary
  end
end

class MCPTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_registry_discovers_mcp_tools_as_rubot_tools
    client = FakeMCPClient.new
    tools = Rubot::MCP::ToolRegistry.new(client:, namespace: "TestMCP").discover
    tool_class = tools.first

    assert_equal "Rubot::TestMCP::LookupTicketTool", tool_class.name
    assert_equal "lookup_ticket", tool_class.mcp_tool_name
    assert_equal [:ticket_id], tool_class.input_schema.fields.map(&:name)
    assert_equal [:ticket_id, :status], tool_class.output_schema.fields.map(&:name)
  end

  def test_mcp_backed_tool_executes_through_normal_tool_path
    client = FakeMCPClient.new
    tool_class = Rubot::MCP::ToolRegistry.new(client:, namespace: "AuditMCP").discover.first
    run = Rubot::Run.new(name: "AuditRun", kind: :agent, input: {}, persist: false)

    output = tool_class.new.execute(input: { ticket_id: "t_123" }, run: run)

    assert_equal({ ticket_id: "t_123", status: "open" }, output)
    assert_equal "lookup_ticket", client.calls.first[:name]
    assert_equal true, run.tool_calls.first[:remote]
    assert_equal "mcp", run.tool_calls.first[:remote_protocol]
    assert_equal "lookup_ticket", run.tool_calls.first[:remote_tool_name]
  end

  def test_agent_can_use_discovered_mcp_tool_via_provider_tool_loop
    client = FakeMCPClient.new
    discovered_tool = Rubot::MCP::ToolRegistry.new(client:, namespace: "LoopMCP").discover.first
    MCPToolAgent.tools(discovered_tool)

    provider = MCPProvider.new(
      [
        {
          content: "Need remote lookup.",
          tool_calls: [{ id: "call_1", name: discovered_tool.name.split("::").last, arguments: { ticket_id: "t_123" } }]
        },
        {
          output: { summary: "remote lookup complete" }
        }
      ]
    )

    Rubot.configure { |config| config.provider = provider }

    run = Rubot.run(MCPToolAgent, input: { ticket_id: "t_123" })

    assert_equal :completed, run.status
    assert_equal "remote lookup complete", run.output[:summary]
    assert_equal true, run.tool_calls.first[:remote]
    assert_equal "lookup_ticket", run.tool_calls.first[:remote_tool_name]
    assert_equal "lookup_ticket", client.calls.first[:name]
  end
end
