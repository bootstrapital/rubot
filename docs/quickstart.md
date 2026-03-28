# Quickstart

This guide is the shortest path from zero to a running Rubot workflow, but it also covers the main runtime concepts and local Rails setup that were previously in the root README.

## What Rubot Is

Rubot is workflow infrastructure built on Rails for agent-assisted operational software with workflow state, approvals, replay, and human oversight.

If you only need a one-off script, Rubot is usually too much. The framework becomes useful when an AI-assisted task needs to live as a durable business process with checkpoints, approvals, auditability, and predictable failure handling.

The strongest in-process adoption path today is a Rails app, but the bigger idea is not "Rails workflow helpers." The bigger idea is a code-owned workflow runtime that gives generated or hand-written operational software a durable structure.

The intended Rails shape is:

- app routes, controllers, and views compose the product-facing UI
- `Operation`, `Workflow`, `Agent`, and `Tool` hold execution logic
- the Rubot admin UI is a separate governance surface for runs, approvals, replay, and traces

That makes Rubot a good fit for teams that want more than happy-path automation:

- ops teams building operational software through code generation
- Rails teams that want a real framework shape under generated code
- internal platforms that need approvals, replay, and governance as first-class concerns

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

The current product story is strongest in Rails, but the architectural value is broader:

- durable runs
- explicit workflow state
- human approval points
- replay and traceability
- code that engineering can inherit without starting from generated glue

## Install

Add Rubot to your Gemfile:

```ruby
gem "rubot", path: "../rubot"
```

Then require it:

```ruby
require "rubot"
```

If you are evaluating Rubot strategically, the right comparison is usually not "can this replace a one-off script?" It is "does this give my generated or hand-authored operational workflow a structure I can trust later?"

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

In the zero-config path, Rubot can use the agent's instructions and schemas directly to produce structured output. Add a custom `perform` only when you need bespoke control over provider calls or tool use.

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

The important pattern is: the agent advises, the workflow decides. Let the model return structured judgment, then let normal Ruby workflow code enforce thresholds, approvals, and final business rules.

For repetitive step wiring, Rubot also ships small input helpers that compile down to the same runtime path as raw lambdas:

```ruby
class TicketTriageWorkflow < Rubot::Workflow
  tool_step :fetch_ticket,
            tool: FetchTicket,
            input: from_input(:ticket_id)

  agent_step :triage_ticket,
             agent: TriageTicketAgent,
             input: from_state(:fetch_ticket)
end
```

Use helpers for the common "pull from input/state/context" cases. Keep raw lambdas for real branching or heavier shaping logic.

You can also compose helpers for small reshaping cases:

```ruby
tool_step :prepare_payload,
          tool: PreparePayload,
          input: merge(
            slice(from_state(:fetch_ticket), :ticket_id, :priority),
            from_context(:channel)
          )
```

When the workflow already has the final data it needs in `run.state`, you can also skip a boilerplate `finalize` step:

```ruby
class TicketTriageWorkflow < Rubot::Workflow
  tool_step :fetch_ticket, tool: FetchTicket, input: from_input(:ticket_id)
  agent_step :triage_ticket, agent: TriageTicketAgent, input: from_state(:fetch_ticket)

  output :triage_ticket
end
```

Use `output` for simple exposure or reshaping. Keep an explicit terminal step when the finish phase contains real business logic.

## Calling APIs From Tools

When a tool needs to call an external API, prefer `Rubot::HTTP` rather than open-coding request logic each time.

```ruby
class FetchTicket < Rubot::Tool
  input_schema do
    string :ticket_id
  end

  output_schema do
    string :ticket_id
    string :subject
  end

  def call(ticket_id:)
    response = Rubot::HTTP.get(
      "https://api.example.com/tickets/#{ticket_id}",
      headers: { "Authorization" => "Bearer #{ENV.fetch("API_TOKEN")}" }
    )

    {
      ticket_id: response.body.fetch("id"),
      subject: response.body.fetch("subject")
    }
  end
end
```

`Rubot::HTTP` is a thin Faraday-backed helper. It handles request execution, JSON parsing, configurable timeouts and retries, and raises `Rubot::HTTPError` for failed responses.

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

In practice, a useful split is:

- tools return facts
- agents return judgment
- workflows own control flow and policy
- operations provide the app-facing feature boundary

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

If you want to inspect a fuller Rails-shaped example, the repository also includes [`sample_app`](../sample_app) with:

- app-facing controllers and views
- a Rubot-backed resume screening capability
- generated install wiring and the mounted admin engine

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
For the repo-level runtime and Rails packaging view, see [Architecture](./architecture.md).

If an operation owns multiple workflows, you can also declare named entrypoints so controllers call the capability in business terms instead of repeating workflow and trigger names:

```ruby
class ProcessImprovementOperation < Rubot::Operation
  workflow :current_state, CurrentStateWorkflow, default: true
  workflow :future_state, FutureStateWorkflow

  trigger :future_state_design, workflow: :future_state

  entrypoint :current_state, workflow: :current_state
  entrypoint :future_state, trigger: :future_state_design
end

ProcessImprovementOperation.launch_future_state(payload: { brief_id: "p_123" })
```

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

This is one of Rubot's biggest practical advantages. A human approval that pauses a run for three days is still the same durable run, with the same state and trace history, rather than a custom state machine you have to rebuild for each feature.

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

Use that document as the current API contract:

- `Rubot::Tool`, `Rubot::Agent`, `Rubot::Workflow`, `Rubot::Run`, stores, policy adapters, and middleware bases are stable public surfaces
- `Rubot::Operation` and admin engine hooks are functional and supported but remain provisional during signature refinement
- runtime helpers like `Rubot::Executor`, `Rubot::Async`, jobs, presenters, records, and `rubot_*` internals are not supported application entrypoints

Additional references:

- [Concepts](./concepts.md)
- [Architecture](./architecture.md)
- [Operation Flow Visualization](./operation_flow_visualization.md)
- [Admin Guide](./admin.md)
- [MCP Tool Integration](./mcp_tool_integration.md)
- [Basic workflow example](../examples/basic_workflow.rb)
- [Tech spec](../tech-spec.md)
