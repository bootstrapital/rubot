import { Agent, Step, Workflow } from '@mastra/core';
import express from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const app = express();

// 1. Mastra Workflow setup
const billingDisputeWorkflow = new Workflow('billing-dispute')
  .addStep(fetchData)
  .addStep(analyzeDiscrepancy)
  .commit();

// 2. Persistence Layer for approvals
// Mastra doesn't have native "approval" primitives, so we build it.
app.post('/dispute/resolve', async (req, res) => {
  const { invoiceId, customerId } = req.body;
  
  // Start the run
  const run = await billingDisputeWorkflow.execute({ invoiceId, customerId });
  const result = run.getStepResult('analyze');

  // Policy check
  if (result.suggestedCredit > 100) {
    // Save state manually to DB because Mastra is ephemeral
    await prisma.disputeRun.create({
      data: {
        mastraRunId: run.id,
        status: 'AWAITING_APPROVAL',
        state: JSON.stringify(run.getContext().getAllStepResults()),
      },
    });
    return res.status(202).json({ runId: run.id, status: 'PENDING_APPROVAL' });
  }

  return res.json({ status: 'COMPLETED', result });
});

// 3. Resuming Workflow from Human Input
app.patch('/dispute/approve/:id', async (req, res) => {
  const { id } = req.params;
  const { decision } = req.body;

  const savedRun = await prisma.disputeRun.findUnique({ where: { id } });
  
  if (decision === 'approve') {
    // Manually trigger the "Finalize" logic
    // We have to re-read the context from DB because the initial run is gone
    const context = JSON.parse(savedRun.state);
    const amount = context['analyze'].suggestedCredit;
    
    await billingSystem.issueCredit(amount);
    await prisma.disputeRun.update({
      where: { id },
      data: { status: 'COMPLETED' },
    });
    
    return res.json({ status: 'DONE' });
  }
});

app.listen(3000);
