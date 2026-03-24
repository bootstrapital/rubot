# Rubot API Nouns and Verbs

This document explains Rubot's desired-state API shape. It is not limited to what exists in the codebase today. The goal is to make the conceptual model explicit so the framework can evolve toward a coherent developer experience instead of accumulating unrelated primitives.

The anchor idea is:

- `Operation` is the top-level product and authoring primitive.
- `Workflow` is the execution graph inside an operation.
- `Agent` is the reasoning primitive.
- `Tool` is the explicit action primitive.

In Rails terms, that does **not** mean `Operation` replaces controllers, routes, or app views.
The desired model is:

- the Rails app owns request handling, page composition, uploads, auth, and surrounding product UI
- the `Operation` owns the business/runtime feature boundary
- the Rubot admin surface owns cross-operation inspection and governance

## Design Intent

Rubot should let developers build internal software with AI the same way they build normal application features:

- define a business unit of work
- attach execution logic
- attach triggers
- attach UI
- attach policies
- inspect and govern the resulting runs

For small use cases, that should fit in one place. For larger systems, the same concepts should split cleanly into separate files and modules.

Rubot should therefore feel like a Rails extension, not a parallel application framework.

## Core Nouns

### Operation

An `Operation` is the business and runtime feature boundary for a Rubot feature.

An operation may own:

- tools
- agents
- workflows
- triggers
- memory configuration
- middleware
- UI
- policies
- fixtures or examples

An operation answers:

- what is this internal tool or workflow feature?
- how does it start?
- what logic and reasoning are involved?

Example mental model:

- `RefundReviewOperation`
- `CustomerEscalationOperation`
- `InvoiceIntakeOperation`

An operation is larger than a workflow. It is the feature boundary.

An operation is **not** the same thing as the full Rails UI surface. In a Rails app, the operation should usually be invoked from normal controllers, routes, and views.

### Workflow

A `Workflow` is the orchestration graph inside an operation.

A workflow answers:

- what steps happen?
- in what order?
- where do humans review?
- when does execution branch, retry, or resume?

A workflow coordinates:

- steps
- agent steps
- tool steps
- approval steps
- branching
- resumptions

An operation may contain one workflow or multiple workflows.

### Agent

An `Agent` is a reasoning participant.

An agent answers:

- given this context, what should be concluded, proposed, or requested next?

An agent may have:

- instructions
- model configuration
- tool access
- input schema
- output schema
- memory configuration
- middleware

In the desired state, agent properties can be partly dynamic at runtime, especially:

- instructions
- model
- available tools

### Tool

A `Tool` is an explicit application action.

A tool answers:

- what concrete action can the system take?

Examples:

- look up a record
- write a note
- fetch a document
- create a task
- send a notification

Tools should remain:

- typed
- auditable
- policy-aware
- safe to expose to agents

### Run

A `Run` is a concrete execution instance.

A run answers:

- what happened for this specific invocation?

A run tracks:

- input
- state
- output
- current step
- status
- events
- approvals
- tool calls
- errors

Runs are durable and inspectable.

### Approval

An `Approval` is a human control point inside execution.

An approval answers:

- who needs to review this?
- by when?
- what decision did they make?

Approvals may include:

- role requirement
- assigned approver
- SLA due time
- expiry time
- approve / reject / request changes decision
- rationale

### Event

An `Event` is a structured trace record for significant activity.

Events answer:

- what happened?
- when did it happen?
- in what step or context?

Events are the backbone of:

- debugging
- operator UI
- replay
- observability

### Memory

`Memory` is the layer that shapes what prior information is available to future reasoning.

Rubot should distinguish between:

- durable history: the full canonical audit trail
- model context: the curated subset sent into the LLM

This distinction matters because long-running operations need context management without losing trust.

### Middleware

`Middleware` is the execution perimeter around an agent or other runtime boundary.

Middleware answers:

- what checks or transformations happen before and after reasoning?

Typical middleware concerns:

- authorization
- prompt guardrails
- redaction
- logging
- rate limits
- tenant scoping

### Trigger

A `Trigger` is a way an operation starts or advances.

Examples:

- manual operator action
- webhook
- scheduled job
- lifecycle event from a subject record
- internal API call

This is important because webhooks, queues, and cron should be thought of as operation ingress, not disconnected plumbing.

In a Rails app, that often means:

- a controller action triggers an operation
- a webhook endpoint triggers an operation
- a job or schedule triggers an operation

The ingress is Rails-native; the unit of work is the operation.

### Subject

A `Subject` is the application record or business entity the operation is attached to.

Examples:

- `Ticket`
- `Invoice`
- `Customer`
- `Dispute`

The subject gives Rubot a natural home in the Rails app.

### UI Surface

A `UI Surface` is the operator-facing presentation for an operation.

Examples:

- start form
- run detail page
- approval panel
- trace view
- subject-side embedded panel
- admin console workbench

The desired state is that operation-facing UI is associated with the operation model, not treated as an afterthought.

But this should not be read as “the operation owns all Rails rendering.” The better Rails pattern is:

- app controllers and routes compose product-facing UI
- those app surfaces invoke operations
- the operation remains the source of truth for execution
- the Rubot admin UI remains a separate governance surface

So there are two distinct UI concerns:

- operation-facing app UI: start forms, embedded panels, subject pages, domain workflows
- admin/governance UI: runs, approvals, replay, traces, metrics, cross-operation inspection

Those can live in the same Rails app, but they should remain conceptually distinct.

### Controller

A Rails `Controller` is still the request/response composition layer.

Controllers answer:

- what route is being served?
- what params or uploads are accepted?
- what app-facing view should render?
- which operation should be invoked?

Controllers should remain responsible for:

- request parsing
- file upload handling
- auth hooks
- redirect/render behavior
- page composition

Controllers should not become the hidden home for agent logic, tool logic, or workflow orchestration. That logic belongs in tools, agents, workflows, and operations.

### Admin Surface

The Rubot admin surface is the governance and inspection UI.

It answers:

- what runs exist across operations?
- what approvals are waiting?
- what happened during execution?
- how do I replay, inspect, and debug a run?

The admin surface is intentionally different from product-facing operation UI.

Good mental split:

- `/ops/...` or other app routes: do the work
- `/rubot/admin/...`: inspect and govern the work

## Core Verbs

### Define

Developers define:

- operations
- workflows
- agents
- tools
- policies
- UI

This is authoring-time structure.

### Trigger

A trigger starts or advances an operation.

Examples:

- `trigger :manual`
- `trigger :webhook`
- `trigger :schedule`

This is how backend concerns like webhooks and cron fit into the model.

### Run

To `run` is to execute a workflow or agent synchronously or asynchronously.

Examples in current Rubot terms:

- `Rubot.run(...)`
- `Rubot.enqueue(...)`

Desired-state meaning:

- start an operation execution
- create a durable run
- begin orchestration

### Reason

To `reason` is for an agent to produce a model-backed response.

This may involve:

- assembling model context
- applying memory processors
- invoking middleware
- calling the provider
- validating output

### Call

To `call` is for an agent or workflow to invoke a tool.

Tool calls should be:

- explicit
- validated
- logged
- replayable

### Approve

To `approve` is to let execution continue through a human checkpoint.

Related verbs:

- reject
- request changes
- expire
- escalate

### Resume

To `resume` is to continue a paused run after:

- approval
- delayed scheduling
- retry
- operator intervention

### Inspect

To `inspect` is to view the run, trace, tool calls, approvals, and outputs.

This is a first-class operator and developer activity, not just a debugging convenience.

### Replay

To `replay` is to reconstruct or re-run prior execution for diagnosis, testing, or auditing.

### Evaluate

To `evaluate` is to score behavior against fixtures, expectations, or regression checks.

### Notify

To `notify` is to emit outward communication about operation state.

Examples:

- approval requested
- workflow failed
- SLA breached
- action completed

## Relationships Between Nouns

The intended hierarchy is:

- an operation contains workflows, agents, tools, triggers, UI, memory config, and middleware
- a workflow orchestrates agents, tools, and approvals
- a run is one execution of an agent or workflow within an operation
- events, approvals, and tool calls belong to a run
- a subject anchors a run in application data

That gives Rubot this conceptual stack:

- `Tool`: explicit action
- `Agent`: reasoning
- `Workflow`: orchestration
- `Operation`: product boundary

## Backend Concerns in the Model

Typical backend functionality should be understood as operation infrastructure.

### Webhooks

Webhooks are triggers.

They should map inbound external events into:

- operation selection
- subject lookup
- input normalization
- workflow start

### Queues and Jobs

Queues are execution mechanics.

They should support:

- async run start
- step execution
- delayed resume
- retry
- SLA checks

Rubot should use Rails and Active Job for this, but the intent belongs to the operation.

### Scheduled Work

Cron-like execution is another trigger type.

Examples:

- stale approval sweeps
- nightly enrichment
- recurring review operations

### Controllers and APIs

Controllers and APIs are entrypoints into operations.

They should not replace the operation model. They should delegate into it.

### Notifications

Notifications are operation side effects.

They should be driven by run state, approval state, and policy rules.

## Memory: Desired-State Model

Memory should not mean “dump the whole past conversation into the model.”

Rubot should preserve:

- full durable run history for trust and replay
- shaped model context for efficient reasoning

This implies a processor pipeline over model context.

Important desired-state processors:

### TokenLimiter

Removes older context until the prompt fits under a configured token budget.

Purpose:

- avoid hard model failures
- keep long-running operations viable

### ToolCallFilter

Removes verbose past tool-call chatter from model context when it is not needed.

Purpose:

- save tokens
- keep prompts focused

These processors should never mutate canonical stored history.

## Dynamic Agents: Desired-State Model

Agents should support runtime-resolved properties.

This matters for:

- tenant-aware behavior
- user-role-aware tool exposure
- plan-tier limits
- subject-specific instructions

Likely dynamic fields:

- instructions
- model
- tools
- possibly output schema

The important constraint is that dynamic behavior should still remain inspectable and policy-governed.

## Middleware: Desired-State Model

Middleware should be the perimeter around agent execution.

That means Rubot should have a stable place to plug in:

- authz
- guardrails
- redaction
- logging
- quotas
- tracing

Middleware should happen before broad external tool expansion, not after.

## MCP: Desired-State Model

Rubot should support MCP as an external tool ecosystem, but MCP should enter through Rubot's tool model.

That means:

- discover remote tools
- normalize them into Rubot-compatible tool surfaces
- run them through middleware, policies, approvals, and tracing

MCP should expand integration speed without bypassing Rubot governance.

## UI: Desired-State Model

UI should be thought of in two layers.

### Operation-Level UI

This is the immediate operator surface for a specific feature:

- start form
- approval panel
- run page
- result view

This should be closely coupled to the operation definition.

### Platform-Level UI

This is the admin/operator framework around all operations:

- operator console
- trace viewer
- metrics views
- workbench layouts
- reusable internal-tool components

This should evolve after the runtime and operator behaviors are real enough to design against.

## Small-App DX vs Large-App DX

Rubot should support both of these without changing concepts.

### Small-App Happy Path

For a small internal workflow, a developer should be able to define everything near each other:

- operation
- tools
- agents
- workflow
- UI

This may be one file or one small directory.

### Large-App Decomposition

For more complex systems, the same operation should be able to split into:

- `app/operations`
- `app/tools`
- `app/agents`
- `app/workflows`
- `app/views` or frontend components

The runtime model should not change when code organization changes.

## Desired-State API Shape

The exact syntax may evolve, but the desired shape should feel like this:

```ruby
class RefundReviewOperation < Rubot::Operation
  trigger :manual
  trigger :webhook, path: "/webhooks/refunds"
  trigger :schedule, cron: "0 * * * *"

  memory do
    processor Rubot::Memory::Processors::TokenLimiter, max_tokens: 12_000
    processor Rubot::Memory::Processors::ToolCallFilter
  end

  middleware do
    use Rubot::Middleware::Authorization
    use Rubot::Middleware::PromptGuard
  end

  tool :lookup_charge do
    # ...
  end

  agent :review do
    instructions ->(ctx) { "Review the case for #{ctx[:tenant_name]}" }
    model ->(ctx) { ctx[:premium?] ? "gpt-5" : "gpt-5-mini" }
    tools ->(ctx) { ctx[:allowed_tools] }
  end

  workflow do
    # ...
  end

  ui do
    # ...
  end
end
```

This example is aspirational. The important part is the shape:

- the operation is the feature
- the workflow is the execution graph
- the agent reasons
- the tool acts
- triggers, middleware, memory, and UI belong to the same boundary

## What Exists Today vs Desired State

Today, Rubot already has strong foundations in:

- tools
- agents
- workflows
- runs
- approvals
- provider abstraction
- job-backed execution

The desired-state gaps are mostly in:

- `Operation` as a first-class authoring primitive
- middleware
- memory processors
- dynamic agents
- trigger modeling
- operation-local UI
- MCP integration

That is a good position to be in. The current implementation is not fighting the desired model. It just has not yet elevated all of the desired concepts into first-class API surfaces.

## Summary

Rubot should be understood as a framework where:

- operations package internal-tool features
- workflows orchestrate execution
- agents reason
- tools act
- runs record what happened
- memory shapes model context
- middleware governs the perimeter
- triggers connect backend infrastructure to business intent
- UI makes the system operable by humans

That is the desired-state vocabulary the API should converge toward.
