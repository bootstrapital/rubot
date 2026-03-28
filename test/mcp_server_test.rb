# frozen_string_literal: true

require_relative "test_helper"

class McpServerTest < Minitest::Test
  class McpTestOperation < Rubot::Operation
    workflow :default, default: true do
      step :test
      def test
        run.state[:res_payload] = { res: "ok:#{run.input[:val]}" }
      end
      output :res_payload
    end
  end

  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
    @server = Rubot::MCP::Server.new(operations: [McpTestOperation])
  end

  def test_list_tools_returns_operation_descriptors
    tools = @server.list_tools
    assert_equal 1, tools.length
    assert_equal "McpServerTest__McpTestOperation", tools.first[:name]
    assert_equal "object", tools.first[:inputSchema][:type]
  end

  def test_call_tool_launches_operation_and_returns_content
    result = @server.call_tool("McpServerTest__McpTestOperation", { val: "123" })
    
    assert_equal false, result[:isError]
    assert_equal "{\"res\":\"ok:123\"}", result[:content].first[:text]
  end

  def test_call_tool_handles_missing_operation
    assert_raises(RuntimeError, "Operation not found") do
      @server.call_tool("UnknownOp")
    end
  end
end
