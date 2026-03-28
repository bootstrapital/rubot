import { Agent, Step, Workflow } from '@mastra/core';
import { z } from 'zod';

// 1. Define the Agent
const billingAnalyst = new Agent({
  name: 'Billing Analyst',
  instructions: 'Review usage logs vs invoice to suggest a credit amount.',
  model: 'gpt-4o',
});

// 2. Define the Steps
const fetchData = new Step({
  id: 'fetch-data',
  inputSchema: z.object({ invoiceId: z.string(), customerId: z.string() }),
  execute: async ({ input }) => {
    // Call Billing & Telemetry APIs
    return { invoice: { total: 1250.0 }, usageLogs: [] };
  },
});

const analyzeDiscrepancy = new Step({
  id: 'analyze',
  execute: async ({ context }) => {
    const data = context.getStepResult('fetch-data');
    const result = await billingAnalyst.generate({ input: data });
    return result;
  },
});

// 3. Define the Workflow
const billingDisputeWorkflow = new Workflow('billing-dispute')
  .addStep(fetchData)
  .addStep(analyzeDiscrepancy)
  .commit();

// Note: Mastra (and most TS frameworks) do not have a built-in "approval_step"
// that halts and persists execution out-of-the-box.
// You usually have to split the workflow into two parts or manage
// the wait state manually via an external DB.

export async function resolveDispute(invoiceId: string, customerId: string) {
  const run = await billingDisputeWorkflow.execute({ invoiceId, customerId });
  const result = run.getStepResult('analyze');

  if (result.suggestedCredit > 100) {
    // Mastra flows are typically ephemeral.
    // To support approval, you must manually save the state to a DB
    // and provide a webhook/endpoint to resume.
    return { status: 'AWAITING_APPROVAL', runId: run.id };
  }

  return { status: 'COMPLETED', result };
}
