# frozen_string_literal: true

# In a "Raw" Rails app, you manually track state in the DB
# rails generate model BillingDisputeRun status:string input:json state:json

class ResolveBillingDisputeService
  def initialize(invoice_id:, customer_id:)
    @run = BillingDisputeRun.create!(
      status: "running",
      input: { invoice_id: invoice_id, customer_id: customer_id }
    )
  end

  def call
    # 1. Fetch data (Procedural)
    invoice_data = BillingSystem.fetch(invoice_id: @run.input["invoice_id"])
    usage_data = TelemetrySystem.fetch(customer_id: @run.input["customer_id"])
    @run.update!(state: { invoice: invoice_data, usage: usage_data })

    # 2. Analyze (Call LLM manually)
    analysis = OpenAI::Client.new.chat(
      messages: [{ role: "user", content: "Review #{invoice_data} and #{usage_data}" }]
    )
    @run.update!(state: @run.state.merge(analysis: analysis))

    # 3. Check Policy (Manual if/else)
    if analysis[:suggested_credit] > 100
      @run.update!(status: "awaiting_approval")
      # You now have to write custom logic in a controller to resume this
      return { status: "pending_approval", run_id: @run.id }
    end

    # 4. Finalize
    finalize(@run)
  end

  def approve(run_id, operator_id:)
    run = BillingDisputeRun.find(run_id)
    run.update!(state: run.state.merge(approved_by: operator_id))
    finalize(run)
  end

  private

  def finalize(run)
    BillingSystem.issue_credit(amount: run.state[:analysis][:suggested_credit])
    run.update!(status: "completed")
    { status: "done", amount: run.state[:analysis][:suggested_credit] }
  end
end
