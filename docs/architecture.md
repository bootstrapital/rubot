# Rubot Architecture

This guide is for understanding how Rubot fits together as workflow infrastructure with a Ruby runtime plus Rails packaging.

The short version:

- most of Rubot lives in plain Ruby under `lib/rubot`
- Rails integration is layered on through a railtie and engine
- your app owns product UI and request handling
- Rubot owns run execution, workflow state, approvals, tracing, and admin inspection

Rails is the strongest first-class host environment today, but the architectural shape matters beyond Rails-only framing: the core of Rubot is a workflow runtime with governance and durability semantics, not just a handful of Rails helpers.

## The Main Boundary

Rubot adds four authoring primitives:

- `Tool`: explicit application action
- `Agent`: reasoning participant
- `Workflow`: ordered execution graph
- `Operation`: business capability wrapper around one or more workflows

The key distinction is:

- a workflow is the procedure
- an operation is the capability boundary

## Ruby Layer Vs Rails Layer

### Ruby Layer

Most runtime behavior lives under [`lib/rubot`](../lib/rubot):

- execution and orchestration
- DSL metadata
- providers
- stores
- policy hooks
- memory and middleware
- jobs and replay helpers

Important files:

- [`lib/rubot.rb`](../lib/rubot.rb)
- [`lib/rubot/tool.rb`](../lib/rubot/tool.rb)
- [`lib/rubot/agent.rb`](../lib/rubot/agent.rb)
- [`lib/rubot/workflow.rb`](../lib/rubot/workflow.rb)
- [`lib/rubot/operation.rb`](../lib/rubot/operation.rb)
- [`lib/rubot/executor.rb`](../lib/rubot/executor.rb)
- [`lib/rubot/run.rb`](../lib/rubot/run.rb)

### Rails Layer

Rails integration adds:

- the admin engine
- controllers and views
- generators
- config loading through the railtie
- Active Record-backed persistence when the host app chooses it

Important files:

- [`lib/rubot/engine.rb`](../lib/rubot/engine.rb)
- [`lib/rubot/railtie.rb`](../lib/rubot/railtie.rb)
- [`config/routes.rb`](../config/routes.rb)
- [`app/controllers/rubot/application_controller.rb`](../app/controllers/rubot/application_controller.rb)

## How Execution Flows

The usual path is:

1. the app calls `Rubot.run`, `Rubot.enqueue`, `Operation.launch`, or `Operation.enqueue`
2. Rubot builds a [`Rubot::Run`](../lib/rubot/run.rb)
3. the executor runs a workflow or agent
4. steps, tool calls, approvals, and events update the run
5. the run completes, pauses for approval, fails, replays, or resumes later

`Rubot::Run` is the inspection spine of the framework. It holds:

- input
- context
- subject reference
- step state
- public output
- approvals
- tool calls
- events and trace history

## What Lives Where

A good application split is:

- Rails app: routes, controllers, auth, uploads, forms, page composition
- tools: API calls, record loads, writes, exports, file handling
- agents: summarization, classification, recommendation, extraction
- workflows: sequencing, approvals, branching, durable state
- operations: packaging, triggers, entrypoints, shared capability pieces
- admin engine: run history, approvals, replay, and trace inspection

## Configuration Layers

Rubot has two main config surfaces:

- [`Rubot.configure`](../lib/rubot/configuration.rb) for runtime wiring like store, provider, queue names, policy hooks, and HTTP defaults
- `config/rubot.yml` for small declarative global defaults like `provider`, `default_model`, queue names, and feature flags

Agents can also load per-agent YAML for declarative metadata and prompt/model defaults. Ruby still wins when both are present.

## Async And Persistence

Synchronous paths:

- `Rubot.run`
- `Operation.launch`

Async paths:

- `Rubot.enqueue`
- `Rubot.resume_later`
- `Operation.enqueue`

The bare runtime defaults to [`Rubot::Stores::MemoryStore`](../lib/rubot/stores/memory_store.rb). Rails installs usually switch to [`Rubot::Stores::ActiveRecordStore`](../lib/rubot/stores/active_record_store.rb) so runs, approvals, checkpoints, and replay history survive process boundaries.

## Why The Engine Exists

Rubot does not try to become your product UI. The engine exists so the framework can mount a separate admin and governance surface into the host Rails app without taking over application routes.

That is why the normal shape is:

- your app renders the feature
- your app launches operations or workflows
- Rubot admin shows what happened afterwards

## Recommended Reading Order

- [Quickstart](./quickstart.md) for the shortest path to a working app
- [Concepts](./concepts.md) for the workflow-vs-operation decision model
- [Public API](./public_api.md) for the supported surface area
- [Admin Guide](./admin.md) for mounting and operator UI
