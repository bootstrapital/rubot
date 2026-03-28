# frozen_string_literal: true

module BillingOps
  # Operation: entrypoint for the business capability
  class BillingDisputeResolution < Rubot::Operation
    tool :billing_system, BillingOps::Tools::BillingSystemTool
    agent :billing_analyst, BillingOps::Agents::BillingAnalystAgent
    workflow :resolve_dispute, BillingOps::Workflows::ResolveDisputeWorkflow, default: true

    entrypoint :resolve, workflow: :resolve_dispute
  end
end

module BillingOps
  module Tools
    class BillingSystemTool < Rubot::Tool
      description "Fetch invoice and telemetry usage data."
      input_schema { string :invoice_id; string :customer_id }
      output_schema { hash :invoice; array :usage_logs }

      def call(invoice_id:, customer_id:)
        # In a real app, this calls an external API like Stripe or Chargebee
        { invoice: { id: invoice_id, total: 1250.0 }, usage_logs: [{ event: "API_CALL", count: 1000 }] }
      end
    end
  end
end

module BillingOps
  module Agents
    class BillingAnalystAgent < Rubot::Agent
      instructions "Review the usage data against the invoice to detect discrepancies."
      input_schema { hash :invoice; array :usage_logs }
      output_schema { boolean :discrepancy_found; number :suggested_credit; string :reasoning }

      def perform(input:, run:, context:)
        # Agent analyzes the data
        { discrepancy_found: true, suggested_credit: 250.0, reasoning: "Over-counted API calls." }
      end
    end
  end
end

module BillingOps
  module Workflows
    class ResolveDisputeWorkflow < Rubot::Workflow
      tool_step :fetch_data,
                tool: BillingOps::Tools::BillingSystemTool,
                input: from_input(:invoice_id, :customer_id)

      agent_step :analyze,
                 agent: BillingOps::Agents::BillingAnalystAgent,
                 input: from_state(:fetch_data)

      approval_step :vp_approval,
                    role: "vp_finance",
                    reason: "Credit over $100 requires oversight.",
                    if: ->(_input, state, _context) { state.dig(:analyze, :suggested_credit) > 100 }

      step :finalize

      def finalize
        credit = run.state.dig(:analyze, :suggested_credit)
        run.state[:finalize] = { status: "credited", amount: credit, approved: !!run.approvals.last }
      end

      output :finalize
    end
  end
end
