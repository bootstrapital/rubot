# Rubot

Rubot is a Rails-native framework for building agentic internal tools with workflow state, approvals, and human oversight.

This repository now includes a V1 framework skeleton focused on Milestone 1 from [`tech-spec.md`](./tech-spec.md): a usable DSL, a small runtime, Rails hooks, generators, tests, and docs that make the first workflow straightforward to build.

The intended Rails shape is:

- app routes/controllers/views compose the product-facing UI
- `Operation`, `Workflow`, `Agent`, and `Tool` hold the execution logic
- the Rubot admin UI is a separate governance surface for runs, approvals, replay, and traces

## What exists today

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
- a runnable example in [`examples/basic_workflow.rb`](./examples/basic_workflow.rb)

## Quick start

### 1. Define a tool

```ruby
class LookupAccount < Rubot::Tool
  description "Load account context."
  idempotent!

  input_schema do
    string :account_id
  end

  output_schema do
    string :account_id
    string :status
  end

  def call(account_id:)
    {
      account_id: account_id,
      status: "active"
    }
  end
end
```

### 2. Define an agent

```ruby
class ReviewAccountAgent < Rubot::Agent
  instructions { "Review account context and prepare a recommendation." }

  input_schema do
    string :account_id
    string :status
  end

  output_schema do
    string :recommended_action
    string :summary
  end

  def perform(input:, run:, context:)
    {
      recommended_action: context.fetch(:recommended_action, "continue"),
      summary: "Account #{input[:account_id]} is #{input[:status]}"
    }
  end
end
```

### 3. Compose a workflow

```ruby
class AccountReviewWorkflow < Rubot::Workflow
  tool_step :lookup_account,
            tool: LookupAccount,
            input: ->(input, _state, _context) { { account_id: input[:account_id] } }

  agent_step :generate_brief,
             agent: ReviewAccountAgent,
             input: ->(_input, state, _context) { state.fetch(:lookup_account) }

  approval_step :manager_review, role: "ops_manager", reason: "Human review required."

  step :finalize

  def finalize
    run.state[:finalize] = {
      recommendation: run.state.fetch(:generate_brief),
      decision: run.approvals.last&.decision_payload
    }
  end
end
```

### 4. Run and resume it

```ruby
run = Rubot.run(AccountReviewWorkflow, input: { account_id: "acct_123" })

if run.waiting_for_approval?
  run.approve!(approved_by: "manager@example.com")
  Rubot::Executor.new.resume(AccountReviewWorkflow, run)
end

pp run.output
```

Workflow output defaults to the final `run.state` snapshot. That makes the run object useful as both execution record and developer-facing result.

## Developer experience choices

Rubot is optimized around three DX constraints:

- Define typed boundaries early. Tools and agents declare schemas at the edge so mistakes fail fast.
- Keep workflow state inspectable. Every step result lands in `run.state`, and every important action emits events.
- Make Rails adoption incremental. The core runtime works in plain Ruby, while Rails hooks and generators are available when you mount it inside an app.

## Running locally

```bash
ruby -Ilib examples/basic_workflow.rb
ruby -Ilib -Itest test/rubot_test.rb
```

## Rails integration and operator console

If you use Rubot inside Rails, the included Railtie can subscribe Rubot events into `ActiveSupport::Notifications`, and the generators give you an opinionated starting point:

```bash
bin/rails generate rubot:install
bin/rails generate rubot:tool LookupAccount
bin/rails generate rubot:agent ReviewAccount
bin/rails generate rubot:workflow AccountReview
```

The install generator also mounts a simple operator console at `/rubot` with:

- `/rubot/playground`
- `/rubot/runs`
- `/rubot/runs/:id`
- `/rubot/approvals`

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

Subject-bound execution is supported with `Rubot.run_for(subject, ...)`, `Rubot.enqueue_for(subject, ...)`,
and `Operation.launch_for(subject, ...)`. Stores can also look up runs for a subject so existing Rails
record pages can embed Rubot state cleanly.

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

Active Record-backed execution now also includes:

- subject-level concurrency protection for active runs
- durable step checkpoints
- duplicate execution-claim protection for resume jobs
- cancellation support via `run.request_cancellation!`

The console is backed by the configured Rubot store. Right now the default is [`Rubot::Stores::MemoryStore`](./lib/rubot/stores/memory_store.rb), which is useful for local development and demos. Rubot now also includes [`Rubot::Stores::ActiveRecordStore`](./lib/rubot/stores/active_record_store.rb) plus migration templates so a Rails app can persist runs durably.

To use the Active Record store in Rails:

```ruby
# config/initializers/rubot.rb
Rubot.configure do |config|
  config.store = Rubot::Stores::ActiveRecordStore.new
end
```

Then run:

```bash
bin/rails generate rubot:install
bin/rails db:migrate
```

The engine now also includes a lightweight developer playground at `/rubot/playground` for running tools, agents, and workflows against JSON fixture input from the browser.

In other words:

- your app UI answers “how does a user start or interact with this feature?”
- the operation/workflow answers “what runtime logic should happen?”
- the Rubot admin UI answers “what happened, and how do we inspect or govern it?”

## Provider configuration

Rubot now includes a first provider adapter at [`Rubot::Providers::RubyLLM`](./lib/rubot/providers/ruby_llm.rb). Configure it once and agents without a custom `perform` implementation can use it directly.

```ruby
Rubot.configure do |config|
  config.provider = Rubot::Providers::RubyLLM.new(provider_name: "openai")
  config.default_model = "gpt-4.1-mini"
end

class TriageAgent < Rubot::Agent
  instructions { "Review the payload and decide the queue." }
  model "gpt-4.1-mini"

  input_schema do
    string :ticket_id
  end

  output_schema do
    string :queue
    string :summary
  end
end
```

## Runtime model

`Rubot.run` returns a [`Rubot::Run`](./lib/rubot/run.rb) with:

- `status`
- `current_step`
- `input`
- `state`
- `output`
- `events`
- `approvals`
- `tool_calls`

For queue-backed execution, use:

```ruby
run = Rubot.enqueue(AccountReviewWorkflow, input: { account_id: "acct_123" })

pending = Rubot.store.find_run(run.id)
pending.approve!(approved_by: "manager@example.com")
Rubot.resume_later(run.id)
```

`Rubot.enqueue` returns the queued run immediately and hands execution to `Rubot::RunJob` / `Rubot::StepJob`. `Rubot.resume_later` schedules `Rubot::ResumeRunJob`, which reloads the run from the configured store before continuing it.

For replay and comparison during debugging:

```ruby
original = Rubot.run(AccountReviewWorkflow, input: { account_id: "acct_123" })
replay = Rubot.replay(original)
```

Replayed runs keep the same `trace_id`, remember `replay_of_run_id`, and can be compared side-by-side from the engine run page.

## Evals

Rubot now includes a small eval DSL that runs real agents, workflows, or operations against fixtures and applies score thresholds.

```ruby
class TicketRoutingEval < Rubot::Eval
  target TriageAgent

  fixture :billing_ticket,
          input: { ticket_id: "t_123" },
          expected: { queue: "billing", summary: "Route to billing" }

  score :output_match do |result|
    result.output == result.expected
  end

  assert_threshold :output_match, equals: 1.0
end
```

Run a single eval or all loaded evals with:

```bash
rake 'rubot:eval[TicketRoutingEval]'
rake rubot:eval
```

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

## Current scope

This repository now includes Milestone 2 basics, async execution, and the first provider adapter, but it still does not yet include:

- rich operator UI components beyond the basic engine console
- eval runners
- policy adapters

It also now includes a first-party file-actions reference pack in [`lib/rubot/tools/file_actions.rb`](./lib/rubot/tools/file_actions.rb) plus a finance/dispute example in [`examples/dispute_file_review.rb`](./examples/dispute_file_review.rb).

Those are still represented in the spec and the code layout, but not yet implemented.

## Files to read first

- [`tech-spec.md`](./tech-spec.md)
- [`examples/basic_workflow.rb`](./examples/basic_workflow.rb)
- [`lib/rubot/workflow.rb`](./lib/rubot/workflow.rb)
- [`lib/rubot/tool.rb`](./lib/rubot/tool.rb)
- [`lib/rubot/agent.rb`](./lib/rubot/agent.rb)
- [`docs/quickstart.md`](./docs/quickstart.md)
