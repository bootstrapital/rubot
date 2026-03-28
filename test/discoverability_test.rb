# frozen_string_literal: true

require_relative "test_helper"

class DiscoverabilityTest < Minitest::Test
  class DiscoveryTool < Rubot::Tool
    description "A test tool"
    tags :safe
    input_schema { string :val }
  end

  class SensitiveTool < Rubot::Tool
    description "A sensitive tool"
    tags :admin
    input_schema { string :secret }
  end

  class DiscoveryAgent < Rubot::Agent
    description "A test agent"
    tools DiscoveryTool, SensitiveTool
  end

  class DiscoveryOperation < Rubot::Operation
    tool :safe_tool, DiscoveryTool
    tool :admin_tool, SensitiveTool
    agent :main_agent, DiscoveryAgent
    
    workflow :default, default: true do
      step :test
    end
  end

  def test_tool_discovery
    info = DiscoveryTool.discover
    assert_equal "DiscoverabilityTest::DiscoveryTool", info[:name]
    assert_equal "A test tool", info[:description]
    assert_equal ["safe"], info[:tags]
    assert_equal "object", info[:input_schema][:type]
  end

  def test_agent_discover_tools_with_filtering
    agent = DiscoveryAgent.new
    
    # All tools
    tools = agent.discover_tools
    assert_equal 2, tools.length
    assert_equal ["DiscoverabilityTest::DiscoveryTool", "DiscoverabilityTest::SensitiveTool"], tools.map { |t| t[:name] }.sort

    # Filtered by tags
    safe_tools = agent.discover_tools(context: { allowed_tool_tags: [:safe] })
    assert_equal 1, safe_tools.length
    assert_equal "DiscoverabilityTest::DiscoveryTool", safe_tools.first[:name]
  end

  def test_operation_discovery
    info = DiscoveryOperation.discover
    assert_equal "DiscoverabilityTest::DiscoveryOperation", info[:name]
    assert_includes info[:tools].keys, :safe_tool
    assert_includes info[:agents].keys, :main_agent
    assert_includes info[:workflows].keys, :default
  end
end
