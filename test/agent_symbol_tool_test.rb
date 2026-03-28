# frozen_string_literal: true

require_relative "test_helper"

class AgentSymbolToolTest < Minitest::Test
  class SimpleTool < Rubot::Tool
    input_schema { string :value }
    output_schema { string :result }
    def call(value:)
      { result: "seen:#{value}" }
    end
  end

  class SymbolToolAgent < Rubot::Agent
    tools :simple_tool
    
    input_schema { string :value }
    output_schema { string :result }

    def perform(input:, run:, context:)
      # Simulate the default perform's resolution logic
      resolution_context = Rubot::AgentResolutionContext.new(agent: self, run: run, input: input, context: context)
      resolved_tools = resolve_tools(resolution_context)
      
      registry = tool_registry(resolved_tools)
      tool_class = registry["SimpleTool"]
      
      raise "Tool not found by symbol" unless tool_class
      
      result = tool_class.new.execute(input: { value: input[:value] }, run: run)
      { result: result[:result] }
    end
  end

  class SymbolToolOperation < Rubot::Operation
    tool :simple_tool, SimpleTool
    agent :symbol_agent, SymbolToolAgent
    
    workflow :test_wf do
      agent_step :run_agent, agent: :symbol_agent
    end
  end

  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_agent_resolves_tools_by_symbol_from_operation_owner
    run = SymbolToolOperation.launch(workflow: :test_wf, payload: { value: "abc" })

    assert_equal :completed, run.status
    assert_equal "seen:abc", run.output[:run_agent][:result]
  end
end
