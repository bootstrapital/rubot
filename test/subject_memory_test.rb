# frozen_string_literal: true

require_relative "test_helper"

Ticket = Struct.new(:id) unless defined?(Ticket)

class SubjectAwareAgent < Rubot::Agent
  input_schema do
    string :question
  end

  output_schema do
    string :answer
  end

  def perform(input:, run:, context:)
    {
      answer: "#{run.subject_type}:#{run.subject_id}:#{input[:question]}:#{context[:channel]}"
    }
  end
end

class SubjectProvider
  def complete(messages:, **)
    Rubot::Providers::Result.new(
      output: { answer: messages.last[:content].include?("status") ? "provider:ok" : "provider:unknown" },
      provider: "test",
      model: "dummy"
    )
  end
end

class ProviderSubjectAwareAgent < Rubot::Agent
  provider SubjectProvider.new

  input_schema do
    string :question
  end

  output_schema do
    string :answer
  end
end

class SubjectMemoryAdapter < Rubot::Memory::SubjectAdapter
  def fetch(subject:, run:, agent_class:, input:, context:)
    [
      {
        role: :system,
        content: "Subject #{subject.class.name}(#{subject.id}) for #{agent_class.name} on #{context[:channel]} answering #{input[:question]} from #{run.id}"
      }
    ]
  end
end

class SubjectWorkflow < Rubot::Workflow
  agent_step :answer, agent: SubjectAwareAgent
end

class SubjectOperation < Rubot::Operation
  workflow SubjectWorkflow
end

class SubjectMemoryTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
      config.subject_memory_adapter = SubjectMemoryAdapter.new
    end
  end

  def teardown
    Rubot.configure do |config|
      config.subject_memory_adapter = nil
    end
  end

  def test_subject_bound_run_helpers_attach_subject_reference
    ticket = Ticket.new("t_123")

    run = Rubot.run_for(ticket, SubjectWorkflow, input: { question: "status" }, context: { channel: "email" })

    assert_equal "Ticket", run.subject_type
    assert_equal "t_123", run.subject_id
    assert_equal "Ticket:t_123", run.subject_key
  end

  def test_store_can_find_runs_for_a_subject
    ticket = Ticket.new("t_123")
    other = Ticket.new("t_999")

    matching = Rubot.run_for(ticket, SubjectWorkflow, input: { question: "status" }, context: { channel: "email" })
    Rubot.run_for(other, SubjectWorkflow, input: { question: "other" }, context: { channel: "chat" })

    assert_equal [matching.id], Rubot.store.find_runs_for_subject(ticket).map(&:id)
  end

  def test_operation_launch_for_preserves_subject_binding
    ticket = Ticket.new("t_123")

    run = SubjectOperation.launch_for(ticket, payload: { question: "priority" }, context: { channel: "phone" })

    assert_equal "Ticket", run.subject_type
    assert_equal "t_123", run.subject_id
  end

  def test_subject_memory_adapter_emits_context_event
    ticket = Ticket.new("t_123")

    run = Rubot.run_for(ticket, ProviderSubjectAwareAgent, input: { question: "status" }, context: { channel: "email" })
    event = run.events.find { |item| item.type == "memory.subject_context.loaded" }

    assert_equal "Ticket", event.payload[:subject_type]
    assert_equal "t_123", event.payload[:subject_id]
  end
end
