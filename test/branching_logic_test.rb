# frozen_string_literal: true

require_relative "test_helper"

class BranchingWorkflow < Rubot::Workflow
  step :start do |input, state|
    state[:path] = [input[:path]]
  end

  step :if_step, if: ->(input, _state, _context) { input[:go_if] } do |_input, state|
    state[:path] << :if_step
  end

  step :unless_step, unless: ->(input, _state, _context) { input[:stop_unless] } do |_input, state|
    state[:path] << :unless_step
  end

  step :jump_logic do |input, state|
    if input[:jump]
      jump_to :target_step
    end
  end

  step :middle_step do |_input, state|
    state[:path] << :middle_step
  end

  step :target_step do |_input, state|
    state[:path] << :target_step
  end

  choice :choice_step do |input, state|
    if input[:choice] == :a && !state[:loop_done]
      state[:loop_done] = true
      jump_to :middle_step
    elsif input[:choice] == :skip
      skip_to :target_step
    end
  end

  output :path
end

class ApprovalBranchingWorkflow < Rubot::Workflow
  step :start do |_input, state|
    state[:path] = [:start]
  end

  approval_step :approve, role: "admin"

  step :post_approval, if: ->(_input, state, _context) { state[:approved] } do |_input, state|
    state[:path] << :post_approval
  end

  step :otherwise, unless: ->(_input, state, _context) { state[:approved] } do |_input, state|
    state[:path] << :otherwise
  end

  output :path
end

class BranchingLogicTest < Minitest::Test
  def setup
    Rubot.configure do |config|
      config.store = Rubot::Stores::MemoryStore.new
    end
  end

  def test_if_condition_met
    run = Rubot.run(BranchingWorkflow, input: { path: :main, go_if: true, stop_unless: true })
    assert_includes run.output, :if_step
  end

  def test_if_condition_not_met
    run = Rubot.run(BranchingWorkflow, input: { path: :main, go_if: false, stop_unless: true })
    refute_includes run.output, :if_step
  end

  def test_unless_condition_met
    run = Rubot.run(BranchingWorkflow, input: { path: :main, go_if: false, stop_unless: false })
    assert_includes run.output, :unless_step
  end

  def test_unless_condition_not_met
    run = Rubot.run(BranchingWorkflow, input: { path: :main, go_if: false, stop_unless: true })
    refute_includes run.output, :unless_step
  end

  def test_jump_to
    run = Rubot.run(BranchingWorkflow, input: { path: :main, go_if: false, stop_unless: true, jump: true })
    assert_equal [:main, :target_step], run.output
    refute_includes run.output, :middle_step
  end

  def test_no_jump
    run = Rubot.run(BranchingWorkflow, input: { path: :main, go_if: false, stop_unless: true, jump: false })
    assert_equal [:main, :middle_step, :target_step], run.output
  end

  def test_choice_jump_loop
    run = Rubot.run(BranchingWorkflow, input: { path: :main, go_if: false, stop_unless: true, jump: false, choice: :a })
    # Flow: start -> jump_logic (no jump) -> middle -> target -> choice (jump to middle) -> middle -> target -> choice (done)
    assert_equal [:main, :middle_step, :target_step, :middle_step, :target_step], run.output
  end

  def test_approval_resumption_with_conditional
    # 1. Start run, hits approval
    run = Rubot.run(ApprovalBranchingWorkflow)
    assert_equal :waiting_for_approval, run.status
    assert_equal [:start], run.state[:path]

    # 2. Approve with positive decision
    run.pending_approval.approve!(decision_payload: { approved: true })
    run.state[:approved] = true
    
    # 3. Resume
    resumed_run = Rubot::Executor.new.execute_run(run)
    assert_equal :completed, resumed_run.status
    assert_equal [:start, :post_approval], resumed_run.output
    refute_includes resumed_run.output, :otherwise
  end

  def test_approval_resumption_with_conditional_negative
    # 1. Start run, hits approval
    run = Rubot.run(ApprovalBranchingWorkflow)
    assert_equal :waiting_for_approval, run.status

    # 2. Approve with negative decision
    run.pending_approval.approve!(decision_payload: { approved: false })
    run.state[:approved] = false
    
    # 3. Resume
    resumed_run = Rubot::Executor.new.execute_run(run)
    assert_equal :completed, resumed_run.status
    assert_equal [:start, :otherwise], resumed_run.output
    refute_includes resumed_run.output, :post_approval
  end
end
