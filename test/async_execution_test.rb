# frozen_string_literal: true

require_relative "test_helper"

require "active_job"
require "active_job/test_helper"

class AsyncWorkflow < Rubot::Workflow
  step :prepare
  approval_step :review, role: "reviewer", reason: "Human review required"
  step :finish

  def prepare
    run.state[:prepare] = { value: run.input[:value] }
  end

  def finish
    run.state[:finish] = {
      approved_by: run.approvals.last.decision_payload[:approved_by],
      value: run.state[:prepare][:value]
    }
  end
end

class AsyncExecutionTest < Minitest::Test
  include ActiveJob::TestHelper

  def setup
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs

    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def teardown
    clear_enqueued_jobs
    clear_performed_jobs
  end

  def test_enqueue_creates_run_and_processes_to_approval
    run = nil

    perform_enqueued_jobs do
      run = Rubot.enqueue(AsyncWorkflow, input: { value: "abc" })
    end

    persisted = Rubot.store.find_run(run.id)

    assert_equal :waiting_for_approval, persisted.status
    assert_equal "abc", persisted.state[:prepare][:value]
    assert_equal 1, persisted.approvals.length
    assert_includes persisted.events.map(&:type), "run.started"
  end

  def test_resume_later_continues_approved_run
    run = nil

    perform_enqueued_jobs do
      run = Rubot.enqueue(AsyncWorkflow, input: { value: "abc" })
    end

    persisted = Rubot.store.find_run(run.id)
    persisted.approve!(approved_by: "ops@example.com")

    perform_enqueued_jobs do
      Rubot.resume_later(persisted)
    end

    completed = Rubot.store.find_run(run.id)

    assert_equal :completed, completed.status
    assert_equal "ops@example.com", completed.state[:finish][:approved_by]
    assert_equal "abc", completed.output[:finish][:value]
    assert_equal 1, completed.events.count { |event| event.type == "run.completed" }
  end
end
