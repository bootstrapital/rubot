# From Quickstart To Advanced Operations

This guide is for the point where the quickstart stops being enough.

In the quickstart, Rubot can look simple:

- define a tool
- define an agent
- define a workflow
- run it

That is enough to learn the runtime.

As soon as the feature gets more real, though, you run into a different set of questions:

- when is a workflow enough?
- when should I introduce an operation?
- where should tools, agents, and workflows live?
- what belongs in the Rails app versus in Rubot?

This document answers those questions.

Rails is still the strongest in-process host path for Rubot today, but the architectural distinctions here matter more broadly than a Rails-only framing. They are what make Rubot useful as code-owned workflow infrastructure rather than just a handful of helper APIs.

## The Short Version

Use the primitives like this:

- `Tool`: an explicit application action
- `Agent`: a reasoning participant
- `Workflow`: the ordered execution graph
- `Operation`: the business capability that packages one or more workflows

The most important distinction is:

- a `Workflow` is the procedure
- an `Operation` is the business capability that packages one or more workflows

If you remember only one thing, remember that.

## Start Simple

The quickstart path is intentionally small.

For a simple feature, you can often think like this:

- one workflow
- one or two tools
- maybe one agent
- maybe one approval

At that stage, the workflow often feels like the whole feature.

That is fine.

You do **not** need to introduce `Operation` on day one just to be "proper."
If the feature is small and the workflow is the whole story, starting with a workflow is a good move.

## When A Workflow Is Enough

Use a bare workflow when:

- there is one obvious execution path
- the feature is small
- there is little shared configuration around it
- you are still proving the workflow shape
- there is no need yet for multiple entrypoints or grouped feature packaging

In other words, a workflow is enough when the execution graph and the business capability are basically the same thing.

Example:

- `TicketTriageWorkflow`
- `RefundReviewWorkflow`
- `ResumeScreeningWorkflow`

In those cases, introducing `Operation` too early can feel like ceremony.

## When To Introduce An Operation

Introduce an operation when the feature becomes bigger than one execution graph.

That usually happens when one or more of these become true:

- the feature has multiple related workflows
- the feature has multiple entrypoints or triggers
- workflows share the same tools or agents
- the feature needs a stronger business name than one workflow class
- the feature is becoming something you want to package, reuse, or ship as a unit

Examples:

- `RefundReviewOperation`
- `CustomerEscalationOperation`
- `ProcessImprovementOperation`

An operation is where you stop thinking only about "how this run executes" and start thinking about "how this business capability is organized."

## Operation Vs Workflow

This is the line that matters most.

### Workflow

A workflow is the execution graph.

It owns:

- ordered steps
- tool calls
- agent calls
- approvals
- branching
- resumability

It answers:

- what steps happen?
- in what order?
- where does human review happen?
- what happens after approval or rejection?

### Operation

An operation is the business capability.

It owns:

- one or more workflows
- operation-local tools and agents
- triggers and launch rules
- named entrypoints
- the public shape of the capability

It answers:

- what business capability does this represent?
- what workflows belong to it?
- how does the app launch it?
- what are the named entrypoints into this capability?

## A Useful Rule Of Thumb

Ask two questions:

1. "Am I describing one execution path?"
2. "Or am I describing a business capability with multiple paths and shared pieces?"

If it is one execution path, start with a workflow.

If it is a business capability, use an operation and let workflows live inside it.

## How The Pieces Fit

The normal layering should be:

- tools gather or change facts
- agents produce structured judgment
- workflows control sequence and policy
- operations package the business capability
- the Rails app handles routes, controllers, auth, uploads, and product UI

That separation matters because it keeps model output advisory rather than authoritative.

It also matters because it gives generated or hand-written operational software a durable structure. The code can be produced quickly, but it still lands in explicit boundaries instead of dissolving into ad hoc service objects or prompt glue.

A useful operating rule is:

- tools gather facts
- agents make proposals
- workflows decide what actually happens
- operations decide how the business capability is presented and entered

## Inline Vs Separate Files

For small features, it should be possible to define workflows inline inside an operation.

For larger features, it should be possible to split workflows into separate files and point the operation at them.

Both styles are valid.

### Inline Is Good When

- the feature is small
- the workflow is short
- the tools and agents are local to that capability
- keeping the capability in one place improves readability

### Separate Files Are Better When

- the workflow is long
- the operation owns multiple workflows
- tools or agents are shared
- the feature is part of a package or library
- testing and maintenance need clearer seams

That is similar to:

- a small single-file Flask app
- versus a more modular app using blueprints or separate modules

The important part is that the framework should support both without making either one feel second-class.

## The Progression Most Teams Follow

Most features should grow like this:

### Stage 1: One Workflow

You start with:

- one tool
- one agent
- one workflow

This is enough to prove the runtime behavior.

### Stage 2: One Operation Around One Workflow

You introduce an operation when the feature needs:

- a better business name
- triggers
- a cleaner app-facing launch boundary
- shared packaging

At this point, the operation may still point at only one workflow.

That is okay.

### Stage 3: One Operation, Multiple Workflows

This is where `Operation` becomes clearly valuable.

Examples:

- current-state mapping workflow
- future-state design workflow
- SOP generation workflow

They belong to the same feature, share tools and agents, but are not the same execution path.

That is the point where using workflows alone starts to feel awkward.

## Example Mental Model

Take a process improvement capability.

You might have:

- `ProcessImprovementOperation`
- `CurrentStateWorkflow`
- `FutureStateWorkflow`
- `SopDraftWorkflow`

Shared tools:

- load process brief
- fetch artifacts
- export map

Shared agents:

- current state analyst
- future state designer
- SOP drafter

The operation is the capability.
The workflows are the concrete paths inside it.

That is a stronger shape than trying to make one giant workflow do everything.

## What Belongs In Rails Vs Rubot

Rubot does not replace your Rails app.

A good boundary is:

Rails app owns:

- routes
- controllers
- page composition
- auth
- uploads
- the surrounding product UI

Rubot owns:

- tools
- agents
- workflows
- operations
- approvals
- run history
- trace and operator inspection

That boundary is one of the reasons Rubot works well as workflow infrastructure built on Rails: the host app remains the host, while Rubot owns the execution and governance layer.

So in Rails terms:

- controllers should usually launch operations or workflows
- operations should own the business capability runtime boundary
- workflows should own execution logic

## What Exists In Rubot Today

Today Rubot supports:

- `Tool`
- `Agent`
- `Workflow`
- `Operation`
- `Run`, `Approval`, and `Event`
- provider-backed and plain-Ruby agents
- replay and evals
- a mounted admin surface
- dynamic agent resolution
- middleware
- triggers and launch routing on operations
- named workflows within an operation
- named entrypoints on an operation
- workflow input and output helpers for common shaping cases

Strategically, that means Rubot is more than a small workflow helper library. It is a framework for building operational software where agents, approvals, and replay live inside an explicit runtime model.

The main design direction is:

- small features should stay compact
- larger features should scale into operations cleanly
- the framework should reward convention over configuration

## A Practical Decision Tree

If you are building a new feature, ask:

### Do I only have one execution path?

If yes, start with a workflow.

### Do I need multiple related execution paths?

If yes, introduce an operation.

### Do the workflows share tools, agents, or triggers?

If yes, they probably belong under one operation.

### Is this feature becoming package-like?

If yes, definitely use an operation.

That is especially true for a future library like PDT, where the installable unit is a business capability, not just one workflow class.

## Final Guidance

Do not think of `Operation` as a mandatory wrapper around every workflow.

Think of it as the point where a runnable workflow becomes a business capability.

The usual progression is:

- workflow first
- operation once the business capability matters
- multiple workflows inside the operation once the capability gets broader

If a workflow is enough, use a workflow.

If the capability needs a name, packaging, multiple paths, shared components, or trigger routing, use an operation.

If you want the repo-level orientation for how the Ruby runtime and Rails engine fit together, read [Architecture](./architecture.md) after this guide.
