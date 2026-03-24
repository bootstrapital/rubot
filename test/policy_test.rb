# frozen_string_literal: true

require_relative "test_helper"

User = Struct.new(:role) unless defined?(User)

class PolicyGate
  def initialize(actor, request)
    @actor = actor
    @request = request
  end

  def start?
    @actor&.role == "operator"
  end

  def execute_tool?
    @actor&.role == "operator"
  end

  def view?
    @actor&.role == "operator"
  end

  def approve?
    @actor&.role == "manager"
  end
end

class PolicyTool < Rubot::Tool
  policy PolicyGate

  input_schema do
    string :value
  end

  output_schema do
    string :value
  end

  def call(value:)
    { value: value }
  end
end

class PolicyWorkflow < Rubot::Workflow
  policy PolicyGate

  tool_step :echo, tool: PolicyTool
end

class PolicyTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
      config.policy_adapter = Rubot::Policy::PunditAdapter.new
      config.policy_actor_resolver = ->(context, _controller) { context[:actor] }
    end
  end

  def teardown
    Rubot.configure do |config|
      config.policy_adapter = nil
      config.policy_actor_resolver = nil
    end
  end

  def test_runtime_start_authorization_blocks_unauthorized_runs
    error = assert_raises(Rubot::AuthorizationError) do
      Rubot.run(PolicyWorkflow, input: { value: "abc" }, context: { actor: User.new("guest") })
    end

    assert_match(/Not authorized/, error.message)
  end

  def test_runtime_tool_authorization_records_policy_denial
    run = Rubot::Run.new(
      name: PolicyWorkflow.name,
      kind: :workflow,
      input: { value: "abc" },
      context: { actor: User.new("guest") }
    )

    error = assert_raises(Rubot::AuthorizationError) do
      PolicyTool.new.execute(input: { value: "abc" }, run: run)
    end

    assert_match(/Not authorized/, error.message)
    assert_equal :failed, run.status
    assert_includes run.events.map(&:type), "policy.denied"
  end

  def test_runtime_allows_authorized_runs
    run = Rubot.run(PolicyWorkflow, input: { value: "abc" }, context: { actor: User.new("operator") })

    assert_equal :completed, run.status
    assert_equal "abc", run.output[:echo][:value]
  end
end
