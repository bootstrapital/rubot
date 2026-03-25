# Quickstart

This guide is the shortest path from zero to a running Rubot workflow, but it also covers the main runtime concepts and local Rails setup that were previously in the root README.

## What Rubot Is

Rubot is a Rails-native framework for building agentic internal tools with workflow state, approvals, and human oversight.

The intended Rails shape is:

- app routes, controllers, and views compose the product-facing UI
- `Operation`, `Workflow`, `Agent`, and `Tool` hold execution logic
- the Rubot admin UI is a separate governance surface for runs, approvals, replay, and traces

## What Exists Today

- `Rubot::Tool` for typed, explicit application actions
- `Rubot::Agent` for structured reasoning participants
- `Rubot::Workflow` for durable step orchestration with approval pauses
- `Rubot::Operation` for feature-level grouping on top of tools, agents, and workflows
- `Rubot::Run`, `Rubot::Event`, and `Rubot::Approval` runtime objects
- a simple executor with trace capture and workflow resume support
- a provider abstraction plus a first RubyLLM adapter
- subject-bound run helpers and optional subject-scoped memory retrieval
- policy adapters for runtime and admin authorization checks
- execution claims, step checkpoints, and cancellation for safer concurrent execution
- `Rubot::Eval` for fixtures, scoring, and regression checks against real runs
- a first-party file actions tool pack for ingestion, extraction, classification, and brief generation
- Rails integration entry points through a Railtie, store-backed operator console, and generators

## Install

Add Rubot to your Gemfile:

```ruby
gem "rubot", path: "../rubot"
```

Then require it:

```ruby
require "rubot"
```

## Build Your First Flow

### 1. Define a tool

```ruby
class FetchTicket < Rubot::Tool
  description "Load ticket context for a support workflow."
  idempotent!

  input_schema do
    string :ticket_id
  end

  output_schema do
    string :ticket_id
    string :priority
    array :tags, of: :string
  end

  def call(ticket_id:)
    {
      ticket_id: ticket_id,
      priority: "normal",
      tags: ["billing"]
    }
  end
end
```

### 2. Define an agent

Agents consume structured input and emit structured output. They can be plain Ruby objects, or they can use the configured Rubot provider when you omit `perform`.

```ruby
class TriageTicketAgent < Rubot::Agent
  instructions do
    "Review ticket context and recommend routing."
  end

  model "gpt-4.1-mini"

  input_schema do
    string :ticket_id
    string :priority
    array :tags, of: :string
  end

  output_schema do
    string :queue
    string :summary
  end
end
```

Configure the provider once:

```ruby
Rubot.configure do |config|
  config.provider = Rubot::Providers::RubyLLM.new(provider_name: "openai")
  config.default_model = "gpt-4.1-mini"
end
```

### 3. Compose a workflow

```ruby
class TicketTriageWorkflow < Rubot::Workflow
  tool_step :fetch_ticket,
            tool: FetchTicket,
            input: ->(input, _state, _context) { { ticket_id: input[:ticket_id] } }

  agent_step :triage_ticket,
             agent: TriageTicketAgent,
             input: ->(_input, state, _context) { state.fetch(:fetch_ticket) }

  approval_step :supervisor_review, role: "support_supervisor", reason: "Human review required."

  step :finalize

  def finalize
    run.state[:finalize] = {
      triage: run.state.fetch(:triage_ticket),
      approved_by: run.approvals.last&.decision_payload&.fetch(:approved_by, nil)
    }
  end
end
```

### 4. Run and resume it

```ruby
run = Rubot.run(TicketTriageWorkflow, input: { ticket_id: "t_123" })

puts run.status
# => :waiting_for_approval

run.approve!(approved_by: "lead@example.com")
Rubot::Executor.new.resume(TicketTriageWorkflow, run)

pp run.output
```

Workflow output defaults to a public snapshot of the final `run.state`. Internal framework metadata like checkpoints stays on `run.state` and out of `run.output`.

## Mental Model

- `run.input` is the original payload
- `run.state` stores step outputs by step name
- `run.events` is the execution timeline
- `run.approvals` holds approval records
- `run.output` is the workflow's final public state snapshot

## Developer Experience Choices

Rubot is optimized around three DX constraints:

- define typed boundaries early so mistakes fail fast
- keep workflow state inspectable through `run.state` and emitted events
- make Rails adoption incremental so the core runtime still works in plain Ruby

## Running Locally

```bash
ruby -Ilib examples/basic_workflow.rb
ruby -Ilib -Itest test/rubot_test.rb
```

## Rails Integration

Inside a Rails app, use generators to reduce setup:

```bash
bin/rails generate rubot:install
bin/rails generate rubot:tool FetchTicket
bin/rails generate rubot:agent TriageTicket
bin/rails generate rubot:workflow TicketTriage
```

The install generator mounts the admin engine at `/rubot/admin`, writes `config/initializers/rubot.rb`, and configures `Rubot::Stores::ActiveRecordStore` so the generated Rails path is durable by default.

Generated files land in:

- `app/tools`
- `app/agents`
- `app/workflows`
- `app/operations` if you introduce operation-level feature boundaries in your app
- `config/initializers/rubot.rb`

The recommended app structure is:

- product-facing routes and controllers live in your Rails app
- those controllers invoke operations or workflows
- Rubot primitives live in app-level directories like `app/tools`, `app/agents`, `app/workflows`, and `app/operations`
- the Rubot admin engine lives separately, typically under a route like `/rubot/admin`

Once the engine is mounted, `/rubot/admin/playground` gives you a lightweight browser-based surface for running tools, agents, and workflows against fixture JSON while you iterate locally.

For the full mounting, auth, and customization story, see [Admin Guide](./admin.md).

## Runtime Model

`Rubot.run` returns a [`Rubot::Run`](../lib/rubot/run.rb) with:

- `status`
- `current_step`
- `input`
- `state`
- `output`
- `events`
- `approvals`
- `tool_calls`

For queue-backed execution:

```ruby
run = Rubot.enqueue(TicketTriageWorkflow, input: { ticket_id: "t_123" })

pending = Rubot.store.find_run(run.id)
pending.approve!(approved_by: "lead@example.com")
Rubot.resume_later(run.id)
```

`Rubot.enqueue` returns the queued run immediately and hands execution to `Rubot::RunJob` / `Rubot::StepJob`. `Rubot.resume_later` schedules `Rubot::ResumeRunJob`, which reloads the run from the configured store before continuing it.

For replay and comparison during debugging:

```ruby
original = Rubot.run(TicketTriageWorkflow, input: { ticket_id: "t_123" })
replay = Rubot.replay(original)
```

Replayed runs keep the same `trace_id`, remember `replay_of_run_id`, and can be compared side-by-side from the engine run page.

Important event types currently emitted:

- `run.started`
- `step.entered`
- `step.exited`
- `tool.invoked`
- `tool.completed`
- `tool.failed`
- `agent.started`
- `agent.completed`
- `agent.tool_loop.iteration`
- `agent.tool_loop.completed`
- `model.response.received`
- `approval.requested`
- `approval.granted`
- `run.completed`
- `run.failed`

## Subject-Bound Runs And Policy Hooks

Subject-bound execution is supported with `Rubot.run_for(subject, ...)`, `Rubot.enqueue_for(subject, ...)`, and `Operation.launch_for(subject, ...)`.

Stores can also look up runs for a subject so existing Rails record pages can embed Rubot state cleanly.

For authorization, Rubot can wrap runtime and admin actions with a policy adapter:

```ruby
Rubot.configure do |config|
  config.policy_adapter = Rubot::Policy::PunditAdapter.new
  config.policy_actor_resolver = ->(context, controller) { context[:current_user] || controller&.current_user }
end
```

For subject-scoped memory retrieval:

```ruby
class TicketMemory < Rubot::Memory::SubjectAdapter
  def fetch(subject:, **)
    [{ role: :system, content: "Prior notes for ticket ##{subject.id}" }]
  end
end

Rubot.configure do |config|
  config.subject_memory_adapter = TicketMemory.new
end
```

## Active Record Store And Durability

The bare runtime defaults to [`Rubot::Stores::MemoryStore`](../lib/rubot/stores/memory_store.rb), which is useful for local development and demos.

The Rails install generator defaults new apps to [`Rubot::Stores::ActiveRecordStore`](../lib/rubot/stores/active_record_store.rb) and creates the matching tables so runs persist durably out of the box.

To use the Active Record store in Rails:

```ruby
Rubot.configure do |config|
  config.store = Rubot::Stores::ActiveRecordStore.new
end
```

Then run:

```bash
bin/rails generate rubot:install
bin/rails db:migrate
```

Active Record-backed execution also includes:

- subject-level concurrency protection for active runs
- durable step checkpoints
- duplicate execution-claim protection for resume jobs
- cancellation support via `run.request_cancellation!`

## Global YAML Config

Rails apps can declare small framework-wide defaults in `config/rubot.yml`.

Supported first-pass keys include:

- `provider`
- `default_model`
- `queues.run`
- `queues.step`
- `queues.resume`
- `features.admin_live_updates`

Explicit `Rubot.configure` values still win over YAML. See [YAML Configuration](./configuration_yml.md) for the supported shape and merge rules.

## Evals

Rubot includes a small eval DSL that runs real agents, workflows, or operations against fixtures and applies score thresholds.

```ruby
class TicketTriageEval < Rubot::Eval
  target TriageTicketAgent

  fixture :billing_case,
          input: {
            ticket_id: "t_123",
            priority: "normal",
            tags: ["billing"]
          },
          expected: {
            queue: "billing",
            summary: "Route to billing"
          }

  score :output_match do |result|
    result.output == result.expected
  end

  assert_threshold :output_match, equals: 1.0
end
```

Run a single eval or all loaded evals with:

```bash
rake 'rubot:eval[TicketTriageEval]'
rake rubot:eval
```

## API Boundary And Scope

Rubot documents its `public`, `provisional`, and `internal` surfaces in [Public API](./public_api.md).

Use that document as the contract for `v0.2` cleanup work:

- `Rubot::Tool`, `Rubot::Agent`, `Rubot::Workflow`, `Rubot::Run`, stores, policy adapters, and middleware bases are public
- `Rubot::Operation` and admin engine hooks are available but provisional
- runtime helpers like `Rubot::Executor`, `Rubot::Async`, jobs, presenters, records, and `rubot_*` internals are not supported application entrypoints

Additional references:

- [Concepts](./concepts.md)
- [Admin Guide](./admin.md)
- [MCP Tool Integration](./mcp_tool_integration.md)
- [Basic workflow example](../examples/basic_workflow.rb)
- [Tech spec](../tech-spec.md)
