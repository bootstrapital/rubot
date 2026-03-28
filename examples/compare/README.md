# RevOps Comparison: Billing Dispute Resolution

This folder compares how to implement the same RevOps capability, **Usage-Based Billing Dispute Resolution**, using four different architectural styles.

The scenario:

1. Fetch invoice and usage telemetry.
2. Have an LLM-powered step analyze the dispute.
3. Require human review if the proposed credit is greater than $100.
4. Issue the credit and mark the case complete.

The point of the comparison is not to crown a universal winner. It is to show what each approach feels like when the workflow needs:

- structured reasoning
- business-state transitions
- human review
- some degree of persistence, auditability, or replayability

## What This Comparison Is And Is Not

This is a focused implementation comparison, not a full benchmark.

It is most useful for comparing:

- authoring shape
- where state and control flow live
- how much infrastructure the framework gives you for approvals and resumability
- how naturally the approach fits a Rails-hosted internal operations product

It is less useful for comparing:

- raw model quality
- runtime performance
- ecosystem breadth
- every advanced feature of the non-Ruby frameworks

In other words, this comparison is about business-workflow ergonomics, not overall framework supremacy.

## Implementations

### 1. [Rubot](./rubot/operation.rb) (Ruby/Rails)

- Philosophy: durable, Rails-oriented workflow primitives
- Strength in this scenario: approval handling, run state, replay/inspection, and workflow structure are part of the framework model rather than entirely app-authored
- Tradeoff: more opinionated than a bare Rails service layer, and the full value shows up most clearly when you use the Rails integration path

### 2. [Raw Rails](./raw_rails/resolve_service.rb) (Ruby/Rails)

- Philosophy: conventional application code with service objects and Active Record
- Strength in this scenario: minimal abstraction overhead and full control over the shape of the code
- Tradeoff: persistence, resumability, approval handling, tracing, and replay need to be designed directly in the app

### 3. [Mastra AI](./mastra/workflow.ts) (TypeScript)

- Philosophy: modern TypeScript agent/workflow composition
- Strength in this scenario: strong TypeScript ergonomics and a clean fit for step-oriented AI flows
- Tradeoff: a Rails-style long-running approval workflow usually needs more surrounding application code and persistence decisions than Rubot bakes in

### 4. [LangGraph](./langgraph/workflow.py) (Python)

- Philosophy: explicit graph/state-machine orchestration
- Strength in this scenario: very capable graph-oriented control flow, especially when workflows become more dynamic or cyclic
- Tradeoff: for a straightforward business workflow, the explicit graph model can feel heavier than a Rails-native workflow DSL

## Comparison Summary

| Feature | Rubot | Raw Rails | Mastra | LangGraph |
| :--- | :--- | :--- | :--- | :--- |
| **Primary Fit** | Rails-hosted governed workflows | App-specific procedural code | TypeScript AI workflows | Graph-oriented AI orchestration |
| **State Persistence** | Strong Rails path via configured store | App-authored | Framework/app dependent | Framework/app dependent |
| **Human Review Primitive** | Native `approval_step` | App-authored | App-authored | Possible, but more graph-oriented |
| **Audit / Replay Shape** | Run/event model built in | App-authored | Partial / app-authored | Strong graph trace story |
| **Rails Integration** | First-class | Native by definition | None | None |
| **Visualization** | Native Mermaid export | None by default | Some workflow visualization options | Strong graph visualization story |

## How To Read The Tradeoffs

### Where Rubot Looks Strong

Rubot looks strongest when the requirement is not just "call an LLM in a workflow," but:

- persist the work over time
- pause for humans
- resume later
- inspect the run afterward
- fit naturally into a Rails host app with a separate admin/governance surface

That is the main reason Rubot exists, so this scenario is favorable to it.

### Where The Other Approaches Stay Strong

The other approaches remain attractive when:

- you want fewer framework opinions
- your app already has its own workflow/state machinery
- you are not primarily in a Rails environment
- you need graph-oriented orchestration beyond a fairly linear business process

That matters because the right choice depends on what problem you are actually solving.

## About The Complexity Numbers

Any LOC or file-count comparison here should be read as illustrative, not scientific.

Rubot benefits from framework primitives that move persistence, approvals, replay, and admin inspection into shared runtime code. Other approaches often make that supporting infrastructure more explicit inside the example itself.

That does not mean the other frameworks are "bad" or that Rubot is magically free of complexity. It means the complexity is packaged differently.

The most honest interpretation is:

- Rubot tends to compress more of this specific workflow shape into framework conventions
- the alternatives tend to leave more of the workflow infrastructure in application code

## Bottom Line

For this particular problem, Rubot presents well because the scenario matches its intended niche: governed, approval-aware, Rails-hosted operational workflows.

That is a meaningful advantage, but it should be read as a fit argument, not as proof that Rubot is categorically better than every alternative in every setting.
