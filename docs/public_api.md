# Rubot Public API Boundary

This document defines the Rubot API contract and boundary status.

Rubot's strongest first-class host environment today is Rails, but this contract is meant to describe the workflow infrastructure surface itself, not only the Rails-specific packaging around it.

Statuses used here:

- `public`: stable, supported application or extension surface
- `provisional`: functional and supported for use, but may undergo refinement before stabilization
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

These entrypoints are the main in-process control surface today. They are not yet the full machine-to-machine story, but they are the stable starting point for code-owned workflow execution.

Internal counterparts:

- `Rubot::Executor`
- `Rubot::Async`
- `Rubot::Jobs::*`

### `Rubot::HTTP` (`public`)

Supported today as the standard HTTP utility for tool authors:

- `.get`
- `.post`
- `.put`
- `.patch`
- `.delete`
- `.request`

Supported response surface:

- `status`
- `headers`
- `body`
- `raw_body`
- `url`
- `success?`
- `json?`

Supported error surface:

- `Rubot::HTTPError`
  - `#status`: numeric HTTP status code (for response errors)
  - `#headers`: hash of response headers
  - `#body`: parsed or raw response body
  - `#details`: hash containing:
    - `:cause`: normalized symbol (`:timeout`, `:connection_failed`, `:ssl_error`, `:parse_error`, `:response_error`, or `:unknown_error`)
    - `:url`: the requested URL
    - `:original_exception`: the name of the underlying exception class (if applicable)

Public expectations:

- use `Rubot::HTTP` inside tools when issuing API calls
- prefer `json:` payloads over hand-rolled request serialization
- expect normalized JSON parsing and normalized transport / response failures

Internal counterparts:

- Faraday client construction
- retry middleware setup
- response parsing internals

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

Contract note:

- tools are the explicit action boundary of the runtime
- application code and generated code should prefer expressing side effects through tools rather than burying them in agents or workflows

### `Rubot::Agent` (`public`)

Supported subclass surface:

- DSL macros from `Rubot::DSL` used by agents:
  `instructions`, `description`, `tools`, `input_schema`, `output_schema`,
  `before_run`, `after_run`, `policy`, `memory`, `provider`, `model`, `tags`,
  `metadata`, `config_file`, `use`, `playground_fixture`
- instance method:
  `#perform`

Notes:

- agents may either implement `#perform` directly or rely on a configured provider
- middleware classes passed via `use` are part of the public extension perimeter
- per-agent YAML may supply declarative values for `instructions`, `model`,
  `description`, `tags`, and `metadata`

Contract note:

- agents are reasoning participants, not the whole workflow model
- the public surface assumes agent output remains one part of a broader governed runtime

Internal agent runtime surface:

- provider/tool loop implementation
- `#run`
- tool-call normalization and resolution internals
- `rubot_*` reader methods used internally by the framework

### `Rubot::Workflow` (`public`)

Supported subclass surface:

- workflow DSL:
  `step`, `tool_step`, `agent_step`, `approval_step`, `compute`, `on_failure`,
  `output`
- workflow input helpers:
  `from_input`, `from_state`, `from_context`, `slice`, `merge`
- workflow visualization helpers:
  `.flow_graph`, `.flow_mermaid`
- instance step methods invoked by `step`

Internal workflow runtime surface:

- `#execute`
- `#resume`
- checkpoint/resume bookkeeping
- step input resolution internals

Contract note:

- workflows are the main procedural boundary of the runtime
- they are where human approvals, sequencing, and durable state become explicit

### `Rubot::Operation` (`provisional`)

Supported today as the top-level business capability authoring surface.

Supported subclass surface:

- `.workflow`
- `.agent`
- `.tool`
- `.tools`
- `.trigger`
- `.triggers`
- `.entrypoint`
- `.entrypoints`
- `.flow_graph`
- `.flow_mermaid`
- `.ui`
- `.memory`
- `.launch`
- `.launch_for`
- `.enqueue`
- `.enqueue_for`
- `.runnable`
- `.find_trigger`
- `.resolve_launch`

Supported behavior today:

- one operation may package multiple named workflows
- one workflow may be marked as the default workflow
- workflows may be declared inline or passed as separate classes
- tools and agents may be registered by name and referenced from operation-owned workflows
- triggers may route to a named workflow
- `.launch` / `.enqueue` may target a named workflow explicitly

Why provisional:

- `Operation` is now the recommended pattern for business capability authoring, but its `ui` DSL, trigger naming,
  and final launch/entrypoint conventions are still undergoing signature refinement before stabilization.

Direction note:

- `Operation` is a core part of Rubot's workflow-infrastructure story because it packages workflows, tools, agents, triggers, and entrypoints into a capability boundary.
- the concept is stable and strategically important even while specific parts of its API surface remain provisional.

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
- `Rubot::Run` is the durable execution unit of the runtime, not just a convenience return object

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
- `http_timeout`
- `http_open_timeout`
- `http_retry_attempts`

Provisional configuration hooks:

- `admin_authorizer`
- `subject_locator`

Why provisional:

- both are functional today but may undergo refinement to support more complex PDT-era packaging and subject embedding patterns.

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

Contract note:

- the core runtime is not coupled to Active Record
- Rails is the strongest durable adoption path today, but the store abstraction is part of the broader workflow-infrastructure surface

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

This mount path, the route set, and packaging of the engine remain provisional as we refine the standalone admin packaging and extraction story.

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

It remains provisional while the admin packaging surface stabilizes.

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

- `Rubot::Operation` still needs a tighter final contract, especially around `ui`, trigger naming, and named entrypoint semantics
- admin route shape and engine packaging should be finalized before documenting them as stable
- the `rubot_*` DSL readers are intentionally internal, but their current visibility makes them easy to depend on accidentally
- runtime-owned mutators on `Rubot::Run` are public Ruby methods today even though they are not meant as application entrypoints
