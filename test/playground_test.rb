# frozen_string_literal: true

require_relative "test_helper"

class PlaygroundFixtureTool < Rubot::Tool
  input_schema do
    string :value
  end

  output_schema do
    string :value
  end

  playground_fixture :sample, input: { value: "fixture_value" }, context: { source: "playground" }

  def call(value:)
    { value: value }
  end
end

class PlaygroundFixtureAgent < Rubot::Agent
  input_schema do
    string :value
  end

  output_schema do
    string :echo
  end

  def perform(input:, run:, context:)
    { echo: "#{input[:value]}:#{context[:source]}" }
  end
end

class PlaygroundFixtureWorkflow < Rubot::Workflow
  tool_step :echo, tool: PlaygroundFixtureTool
end

class PlaygroundTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_registry_lists_runnable_classes
    registry = Rubot::Playground::Registry.new

    assert_includes registry.classes(:tool), PlaygroundFixtureTool
    assert_includes registry.classes(:agent), PlaygroundFixtureAgent
    assert_includes registry.classes(:workflow), PlaygroundFixtureWorkflow
  end

  def test_fixture_set_uses_declared_playground_fixtures
    fixture = Rubot::Playground::FixtureSet.new(PlaygroundFixtureTool).options.first

    assert_equal :sample, fixture[:name]
    assert_equal({ value: "fixture_value" }, fixture[:input])
    assert_equal({ source: "playground" }, fixture[:context])
  end

  def test_fixture_set_builds_blank_sample_from_schema_when_no_fixture_exists
    fixture = Rubot::Playground::FixtureSet.new(PlaygroundFixtureAgent).options.first

    assert_equal :blank, fixture[:name]
    assert_equal({ value: "value_sample" }, fixture[:input])
  end

  def test_invocation_can_execute_tool_runs
    run = Rubot::Playground::Invocation.new.call(
      kind: :tool,
      runnable: PlaygroundFixtureTool,
      input: { value: "hello" },
      context: { source: "test" }
    )

    assert_equal :completed, run.status
    assert_equal :tool, run.kind
    assert_equal({ value: "hello" }, run.output)
    assert_equal 1, run.tool_calls.length
  end

  def test_invocation_can_execute_agents_and_workflows
    agent_run = Rubot::Playground::Invocation.new.call(
      kind: :agent,
      runnable: PlaygroundFixtureAgent,
      input: { value: "hello" },
      context: { source: "test" }
    )
    workflow_run = Rubot::Playground::Invocation.new.call(
      kind: :workflow,
      runnable: PlaygroundFixtureWorkflow,
      input: { value: "hello" },
      context: {}
    )

    assert_equal :completed, agent_run.status
    assert_equal({ echo: "hello:test" }, agent_run.output)
    assert_equal :completed, workflow_run.status
    assert_equal({ echo: { value: "hello" } }, workflow_run.output)
  end
end
