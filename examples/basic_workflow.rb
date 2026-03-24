# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rubot"

class LookupAccount < Rubot::Tool
  description "Load a simple account record."

  input_schema do
    string :account_id
  end

  output_schema do
    string :account_id
    string :status
  end

  def call(account_id:)
    {
      account_id: account_id,
      status: "active"
    }
  end
end

class ReviewAccountAgent < Rubot::Agent
  instructions do
    "Review the account context and prepare a recommendation."
  end

  input_schema do
    string :account_id
    string :status
  end

  output_schema do
    string :recommended_action
    string :summary
  end

  def perform(input:, run:, context:)
    {
      recommended_action: context.fetch(:recommended_action, "continue"),
      summary: "Account #{input[:account_id]} is #{input[:status]}"
    }
  end
end

class AccountReviewWorkflow < Rubot::Workflow
  tool_step :lookup_account,
            tool: LookupAccount,
            input: ->(input, _state, _context) { { account_id: input[:account_id] } }

  agent_step :generate_brief,
             agent: ReviewAccountAgent,
             input: ->(_input, state, _context) { state.fetch(:lookup_account) }

  approval_step :manager_review, role: "ops_manager", reason: "Human approval required before final action."

  step :finalize

  def finalize
    decision = run.approvals.last&.decision_payload || {}
    run.state[:finalize] = {
      recommendation: run.state.fetch(:generate_brief),
      decision: decision
    }
  end
end

run = Rubot.run(AccountReviewWorkflow, input: { account_id: "acct_123" }, context: { recommended_action: "monitor" })
puts JSON.pretty_generate(run.to_h)

if run.waiting_for_approval?
  run.approve!(approved_by: "manager@example.com", note: "Looks good")
  Rubot::Executor.new.resume(AccountReviewWorkflow, run)
  puts JSON.pretty_generate(run.to_h)
end
