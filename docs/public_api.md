# Rubot Public API Boundary

This document defines the current Rubot API contract for `v0.2` cleanup work.

Statuses used here:

- `public`: supported application or extension surface
- `provisional`: available to use, but expected to tighten before `v1.0`
- `internal`: framework implementation detail; avoid depending on it directly

## Public Runtime Entrypoints

These are the supported top-level entrypoints for application code:

- `Rubot.configure`
- `Rubot.run`
- `Rubot.run_for`
- `Rubot.enqueue`
- `Rubot.enqueue_for`
- `Rubot.resume_later`
- `Rubot.replay`
- `Rubot.store`
- `Rubot.provider`

Public expectations:

- `Rubot.run*` and `Rubot.enqueue*` return or target a `Rubot::Run`
- `Rubot.configure` is the stable place to wire stores, providers, policy, and runtime defaults
- apps should prefer these entrypoints over direct `Executor` or job usage

Internal counterparts:

- `Rubot::Executor`
- `Rubot::Async`
- `Rubot::Jobs::*`

## Public Authoring Primitives

### `Rubot::Tool` (`public`)

Supported subclass surface:

- DSL macros from `Rubot::DSL` used by tools:
  `description`, `input_schema`, `output_schema`, `policy`
- tool-specific class methods:
  `idempotent!`, `timeout`, `retry_on`, `audit_metadata`
- instance method:
  `#call`

Internal tool runtime surface:

- `#execute`
- retry wrapping and event emission internals

### `Rubot::Agent` (`public`)

Supported subclass surface:

- DSL macros from `Rubot::DSL` used by agents:
  `instructions`, `description`, `tools`, `input_schema`, `output_schema`,
  `before_run`, `after_run`, `policy`, `memory`, `provider`, `model`, `use`,
  `playground_fixture`
- instance method:
  `#perform`

Notes:

- agents may either implement `#perform` directly or rely on a configured provider
- middleware classes passed via `use` are part of the public extension perimeter

Internal agent runtime surface:

- provider/tool loop implementation
- `#run`
- tool-call normalization and resolution internals
- `rubot_*` reader methods used internally by the framework

### `Rubot::Workflow` (`public`)

Supported subclass surface:

- workflow DSL:
  `step`, `tool_step`, `agent_step`, `approval_step`, `branch`, `on_failure`
- instance step methods invoked by `step`

Internal workflow runtime surface:

- `#execute`
- `#resume`
- checkpoint/resume bookkeeping
- step input resolution internals

### `Rubot::Operation` (`provisional`)

Supported today, but expected to tighten during `v0.2`:

- `.workflow`
- `.agent`
- `.tool`
- `.tools`
- `.trigger`
- `.triggers`
- `.ui`
- `.memory`
- `.launch`
- `.launch_for`
- `.enqueue`
- `.enqueue_for`
- `.runnable`
- `.find_trigger`
- `.resolve_launch`

Why provisional:

- `Operation` is the intended top-level authoring boundary, but naming, trigger contracts,
  and the relation between operation UI and admin UI are still being normalized

## Public Runtime Records

### `Rubot::Run` (`public`)

Supported consumer surface:

- status predicates like `queued?`, `running?`, `waiting_for_approval?`, `completed?`, `failed?`, `canceled?`, `terminal?`
- execution metadata readers like `id`, `name`, `kind`, `input`, `context`, `subject`, `state`, `output`, `error`, `events`, `approvals`, `tool_calls`
- naming aliases:
  `runnable_name` for `name`, `source_run_id` for `replay_of_run_id`
- approval helpers:
  `pending_approval`, `approve!`, `reject!`, `request_changes!`
- cancellation helpers:
  `request_cancellation!`, `cancel!`
- inspection helpers:
  `subject_type`, `subject_id`, `subject_key`, `replay?`, `to_h`

Internal or framework-owned areas:

- `start!`, `wait_for_approval!`, `complete!`, `fail!`
- event persistence hooks like `add_event`, `add_tool_call`, `add_approval`, `persist!`
- checkpoint storage and `state[:_rubot]`

Contract note:

- `run.output` is the public workflow result
- `run.state` may contain additional framework-owned metadata such as `:_rubot`

### `Rubot::Approval` and `Rubot::Event` (`public`)

These are part of the public run-inspection model and safe to read from application code.
Mutation is expected to happen through the runtime rather than direct low-level editing.

Naming cleanup aliases now exposed on approvals:

- `role` for `role_requirement`
- `assigned_to` as a normalized `{ type:, id: }` hash alongside `assigned_to_type` and `assigned_to_id`

## Public Configuration Surface

Stable `Rubot.configure` attributes:

- `event_subscriber`
- `time_source`
- `id_generator`
- `store`
- `job_retry_attempts`
- `run_job_queue_name`
- `step_job_queue_name`
- `resume_job_queue_name`
- `provider`
- `default_model`
- `default_provider_name`
- `agent_max_turns`
- `features`
- `subject_memory_adapter`
- `policy_adapter`
- `policy_actor_resolver`

Provisional configuration hooks:

- `admin_authorizer`
- `subject_locator`

Why provisional:

- both are tied to the evolving admin packaging and subject embedding story

## Public Store Interfaces

`Rubot::Stores::Base` is a public extension contract.

Required methods:

- `save_run`
- `find_run`
- `all_runs`
- `pending_approvals`
- `find_runs_for_subject`

Optional methods:

- `claim_run_execution`
- `release_run_execution`
- `execution_claims_supported?`

Concrete stores shipped in Rubot:

- `Rubot::Stores::MemoryStore` (`public`)
- `Rubot::Stores::ActiveRecordStore` (`public`, Rails-oriented)

## Public Policy and Middleware Hooks

Public policy extension points:

- `Rubot::Policy.authorize!`
- `Rubot::Policy::BaseAdapter`
- `Rubot::Policy::PunditAdapter`
- `Rubot::Policy::CanCanAdapter`

Public middleware extension points:

- `Rubot::Middleware::Base`
- `Rubot::Middleware::Authorization`
- `Rubot::Middleware::Guardrail`
- `Rubot::DSL#use`

Internal policy and middleware plumbing:

- `Rubot::Policy::Request`
- `Rubot::Middleware::Stack`

Runtime events now prefer additive normalized payload aliases where needed, for example:

- `runnable_name` alongside older `name`
- `run_kind` alongside older `kind`
- `source_run_id` alongside `replay_of_run_id`
- `resource_name` alongside `resource`

## Admin Mount and Customization Hooks

### Mounting the engine (`provisional`)

Supported today:

```ruby
mount Rubot::Engine => "/rubot/admin"
```

This mount path, the route set, and packaging of the engine should be treated as provisional
until the admin extraction work lands.

### Admin auth hook (`provisional`)

Supported today through configuration:

```ruby
Rubot.configure do |config|
  config.admin_authorizer = -> { authenticate_admin! }
end
```

This hook currently supports either:

- `-> { ... }` executed in the controller instance context
- `->(controller) { ... }` with the engine controller passed explicitly

It remains provisional while the admin packaging surface settles during `v0.2`.

### Presenter JSON contracts (`provisional`)

Useful today for frontend work, but not yet declared fully stable:

- `Rubot::Presenters::RunPresenter#as_admin_json`
- `Rubot::Presenters::ApprovalPresenter#as_admin_json`
- `Rubot::Presenters::ToolCallPresenter#as_admin_json`

## Internal Namespace Inventory

Unless explicitly promoted later, these namespaces should be treated as internal:

- `Rubot::Executor`
- `Rubot::Async`
- `Rubot::DSL` internals exposed as `rubot_*` readers
- `Rubot::StepDefinition`
- `Rubot::AgentResolutionContext`
- `Rubot::Playground`
- `Rubot::LiveUpdates`
- `Rubot::Jobs::*`
- `Rubot::Records::*`
- `Rubot::Presenters::*`
- `Rubot::MCP`

## Follow-On Cleanup Notes

This audit surfaced a few cleanup items for later tasks:

- `Rubot::Operation` needs a tighter final contract, especially around `ui`, trigger naming, and launch semantics
- admin route shape and engine packaging should be finalized before documenting them as stable
- the `rubot_*` DSL readers are intentionally internal, but their current visibility makes them easy to depend on accidentally
- runtime-owned mutators on `Rubot::Run` are public Ruby methods today even though they are not meant as application entrypoints
