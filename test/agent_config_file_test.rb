# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "securerandom"

class AgentConfigFakeRubyLLMTransport
  attr_reader :requests

  def initialize(response)
    @response = response
    @requests = []
  end

  def complete(request)
    @requests << request
    @response
  end
end

class AgentConfigFileTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.provider = nil
      config.default_model = "gpt-default"
      config.default_provider_name = nil
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_loads_adjacent_agent_yaml_automatically
    with_agent_fixture(<<~RUBY, <<~YAML) do |agent_class, _dir|
      class GENERATED_AGENT_CLASS < Rubot::Agent
        input_schema do
          string :value
        end

        output_schema do
          string :summary
        end
      end
    RUBY
      instructions: |
        Review the incoming value and summarize it.
      model: gpt-yaml
      description: YAML-backed agent
      tags:
        - intake
        - triage
      metadata:
        owner: ops
        risk_level: medium
    YAML
      assert_equal "Review the incoming value and summarize it.\n", agent_class.instructions
      assert_equal "gpt-yaml", agent_class.model
      assert_equal "YAML-backed agent", agent_class.description
      assert_equal ["intake", "triage"], agent_class.tags
      assert_equal({ owner: "ops", risk_level: "medium" }, agent_class.metadata)
      assert_match(/generated_agent_class\.yml\z/, agent_class.resolved_config_file)
    end
  end

  def test_ruby_declarations_override_yaml_values
    with_agent_fixture(<<~RUBY, <<~YAML) do |agent_class, _dir|
      class GENERATED_AGENT_CLASS < Rubot::Agent
        config_file "generated_agent_class.yml"

        instructions "Ruby instructions win."
        model "gpt-ruby"
        description "Ruby description"
        tags :priority, "manual-review"
        metadata owner: "ruby", risk_level: "high"

        input_schema do
          string :value
        end

        output_schema do
          string :summary
        end
      end
    RUBY
      instructions: YAML instructions
      model: gpt-yaml
      description: YAML description
      tags:
        - intake
      metadata:
        owner: yaml
        risk_level: low
    YAML
      assert_equal "Ruby instructions win.", agent_class.instructions
      assert_equal "gpt-ruby", agent_class.model
      assert_equal "Ruby description", agent_class.description
      assert_equal ["priority", "manual-review"], agent_class.tags
      assert_equal({ owner: "ruby", risk_level: "high" }, agent_class.metadata)
    end
  end

  def test_runtime_uses_yaml_backed_instructions_and_model
    transport = AgentConfigFakeRubyLLMTransport.new(
      output: { summary: "done" },
      model: "gpt-yaml",
      provider: "ruby_llm"
    )

    Rubot.configure do |config|
      config.provider = Rubot::Providers::RubyLLM.new(transport: transport, provider_name: "openai")
      config.default_model = "gpt-default"
      config.default_provider_name = "openai"
      config.store = Rubot::Stores::MemoryStore.new
    end

    with_agent_fixture(<<~RUBY, <<~YAML) do |agent_class, _dir|
      class GENERATED_AGENT_CLASS < Rubot::Agent
        input_schema do
          string :value
        end

        output_schema do
          string :summary
        end
      end
    RUBY
      instructions: |
        Use the YAML prompt.
      model: gpt-yaml
    YAML
      run = Rubot.run(agent_class, input: { value: "abc" })

      assert_equal :completed, run.status
      assert_equal "done", run.output[:summary]
      assert_equal "gpt-yaml", transport.requests.last[:model]
      assert_equal "Use the YAML prompt.\n", transport.requests.last[:messages][0][:content]
    end
  end

  def test_rejects_invalid_agent_yaml_keys
    with_agent_fixture(<<~RUBY, <<~YAML) do |agent_class, _dir|
      class GENERATED_AGENT_CLASS < Rubot::Agent
      end
    RUBY
      unsupported: true
    YAML
      error = assert_raises(Rubot::ValidationError) { agent_class.agent_config }

      assert_includes error.message, "Unsupported Rubot agent config keys"
    end
  end

  private

  def with_agent_fixture(ruby_source, yaml_source)
    Dir.mktmpdir("rubot-agent-config") do |dir|
      constant_name = "GeneratedAgent#{SecureRandom.hex(4)}"
      agent_file = File.join(dir, "generated_agent_class.rb")
      yaml_file = File.join(dir, "generated_agent_class.yml")

      File.write(agent_file, ruby_source.gsub("GENERATED_AGENT_CLASS", constant_name))
      File.write(yaml_file, yaml_source)
      load agent_file

      agent_class = Object.const_get(constant_name)
      yield agent_class, dir
    ensure
      Object.send(:remove_const, constant_name) if Object.const_defined?(constant_name, false)
    end
  end
end
