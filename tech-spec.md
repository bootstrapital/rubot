# Rubot Technical Specification

## 1. Overview

Rubot is a Ruby framework for building agentic internal tools and operational workflows, with a strong emphasis on Rails-native development. Its purpose is to make agentic systems feel like application engineering rather than prompt orchestration glued onto an app as an afterthought.

Rubot is designed for workflows where AI needs to participate in real software systems: support triage, finance exception handling, review queues, internal research and action copilots, and approval-heavy backoffice processes.

The core design principle is that agents are not standalone chat entities. They are application participants that operate on domain records, call explicit tools, advance workflow state, surface proposed actions, and hand work to humans when needed.

## 2. Product Thesis

Most agent frameworks begin with model interaction and then require developers to assemble persistence, state transitions, retries, approvals, UI updates, and auditability around them. Rails teams already have much of this application substrate. Rubot should leverage Rails wherever possible and add the missing primitives for agentic flows.

Rubot should therefore be understood as:

* a Rails-native framework for agentic internal tools
* a workflow runtime for multi-step human-and-agent processes
* an operation framework for packaging workflows, tools, agents, and UI into one developer-facing unit
* a tool system for safe and inspectable actions
* an observability and evaluation layer for agentic execution

## 3. Design Goals

### 3.1 Primary goals

Rubot should:

* feel idiomatic to Ruby and Rails developers
* support multi-step, stateful, resumable workflows
* make human-in-the-loop operations first-class
* treat tools as explicit, permissioned application actions
* integrate cleanly with existing Rails models and service objects
* provide durable execution, auditability, and replayability
* support operator-facing UIs with live progress and intervention points
* remain useful even without a hosted control plane

### 3.2 Non-goals for V1

Rubot should not initially try to be:

* a general-purpose no-code builder
* a model training framework
* a distributed workflow engine at Temporal scale
* a cross-language runtime from day one
* a complete replacement for Rails app architecture

## 4. Framework Boundaries

Rubot should sit above the Rails app layer but within the Rails process and persistence model.

It should provide:

* operation definitions
* agent definitions
* tool definitions
* workflow definitions
* run orchestration
* event and trace capture
* approval and escalation primitives
* memory interfaces
* operator-facing UI helpers
* evaluation hooks

It should rely on Rails for:

* persistence
* background execution
* realtime updates
* routing and controllers
* authentication and authorization integrations
* rendering and application structure

## 5. Key Use Cases

Rubot should be optimized for:

1. Support operations

   * triage inbound issues
   * assemble customer context
   * recommend routing or next action
   * escalate low-confidence cases

2. Finance and exception workflows

   * ingest invoices, disputes, refund requests
   * extract key fields
   * classify cases
   * generate operator-ready review briefs
   * require approval before final action

3. Internal research and action copilots

   * gather context across records and tools
   * summarize accounts or cases
   * produce recommended actions
   * prepare materials for human review

4. Human-supervised multi-step workflows

   * collect evidence
   * call tools
   * pause for approval
   * resume with additional instructions

## 6. Core Abstractions

Rubot should distinguish between runtime primitives and product/DX primitives.

Runtime primitives:

* tools
* agents
* workflows
* runs
* approvals

Product/DX primitives:

* operations
* operator UIs
* eval suites

An operation is the developer-facing unit. A workflow is the execution graph inside that operation.

### 6.0 Operation

An Operation is the top-level authoring primitive for a Rubot feature. It packages the full operator-facing unit, including:

* workflows
* agents
* tools
* memory configuration
* middleware / policy perimeter
* UI definitions or UI configuration

Operations should support a happy path where small internal tools can be defined in one place, while still allowing larger apps to split those concerns across multiple files.

### 6.1 Agent

An Agent is a configured reasoning participant that can:

* receive structured input
* access defined tools
* emit structured output
* interact with workflow state
* generate proposed actions or artifacts

An Agent should not own persistence directly. It should operate within a Run and a Workflow context.

Example shape:

```ruby
class ChargebackReviewAgent < Rubot::Agent
  instructions do
    <<~TEXT
      Review chargeback packets, identify missing evidence, and recommend the next action.
      Do not finalize any decision without human approval.
    TEXT
  end

  tools FileActions::ClassifyDocument,
        FileActions::ExtractFields,
        Accounts::LookupOrder,
        Cases::CreateReviewBrief

  input_schema do
    string :document_id
    string :case_id
  end

  output_schema do
    string :recommended_next_action
    array :missing_information, of: :string
    string :summary
  end
end
```

### 6.2 Tool

A Tool is an explicit application action that an Agent may invoke. It should behave more like a typed service object than an arbitrary function.

A Tool should define:

* input schema
* output schema
* execution logic
* permissions or policy hooks
* audit metadata
* retry characteristics

Example shape:

```ruby
class FileActions::ExtractFields < Rubot::Tool
  input_schema do
    string :document_id
    string :template
  end

  output_schema do
    hash :fields
    float :confidence
    array :warnings, of: :string
  end

  def call(document_id:, template:)
    # implementation
  end
end
```

### 6.3 Workflow

A Workflow is a durable multi-step process coordinating agents, tools, humans, and state transitions. Workflows should be resumable and inspectable.

A Workflow should support:

* step graphs or ordered steps
* conditional transitions
* retries
* approvals
* escalations
* resumptions
* deadlines and timeouts
* event emission

Example shape:

```ruby
class DisputeReviewWorkflow < Rubot::Workflow
  step :ingest_document
  step :classify_document
  step :extract_fields
  step :generate_brief
  approval_step :review_recommendation
  step :finalize_case
end
```

### 6.4 Run

A Run is a concrete execution of an Agent or Workflow against a given subject, input payload, and execution context.

A Run should track:

* current status
* current step
* input payload
* derived state
* emitted events
* tool calls
* outputs
* errors
* approval requirements
* timestamps

### 6.5 Approval

Approvals are first-class control points where human action is required before the workflow can continue.

Approval primitives should support:

* required approver role or policy
* timeout or SLA
* approve / reject / request changes
* approval rationale capture
* resume payloads

### 6.6 Trace/Event

Every significant action should emit structured trace events.

Trace events should include:

* run started
* step entered / exited
* tool invoked / completed / failed
* model response received
* approval requested / granted / denied
* retry scheduled
* run completed / failed / canceled

### 6.7 Memory

Memory should be pluggable and optional.

Rubot should support:

* transient run context
* workflow-scoped state
* record-scoped memory
* external semantic retrieval adapters

Memory should distinguish between:

* durable execution history kept for auditability
* curated model context assembled for each agent turn

Rubot should support memory processors that modify model context without mutating canonical history. Important early processors include:

* token limiting to keep prompts under model limits
* tool-call filtering to remove verbose past tool chatter when it is not needed for future reasoning

Memory should not be assumed for every workflow.

## 7. Rails Leverage: What Rubot Should Reuse

Rubot should lean heavily on Rails primitives instead of reinventing them.

### 7.1 Active Record

Active Record should be the default persistence mechanism for Rubot entities.

Rubot should create Rails models or concerns for:

* runs
* workflow states
* tool calls
* events
* approvals
* memories (optional)
* evaluations

Why leverage Active Record:

* record-centric workflows already live in Rails
* associations are natural for runs, events, and approvals
* transactions are useful for durable step changes
* query interfaces are familiar for operator consoles and analytics

Recommended base models:

* `Rubot::RunRecord`
* `Rubot::ToolCallRecord`
* `Rubot::EventRecord`
* `Rubot::ApprovalRecord`
* `Rubot::EvaluationRecord`

### 7.2 Active Job

Active Job should be the default execution backbone for asynchronous and resumable work.

Rubot should use Active Job for:

* executing workflow steps
* scheduling retries
* delayed resumptions
* timeout checks
* asynchronous tool execution when needed

Why leverage Active Job:

* Rails developers already know it
* Sidekiq / Solid Queue / GoodJob compatibility comes for free
* durable step execution can be implemented in job boundaries

Rubot should add a thin abstraction like:

* `Rubot::RunJob`
* `Rubot::StepJob`
* `Rubot::ResumeRunJob`

### 7.3 Action Cable / Turbo Streams

Realtime updates for operator-facing UIs should leverage Action Cable or Turbo Streams.

Rubot should use these for:

* live run progress
* trace updates
* approval notifications
* operator console refreshes

Why this matters:

* agentic internal tools are much more useful when humans can watch progress
* Rails already supports live updates cleanly

### 7.4 Action Controller / Routing

Controllers and routes should expose:

* operator views
* approval actions
* replay actions
* run inspection pages
* tool playgrounds

Rubot can provide mountable engines or route helpers for:

* `/rubot/runs`
* `/rubot/approvals`
* `/rubot/tools`
* `/rubot/evals`

### 7.5 Active Support

Rubot should rely on Active Support for:

* instrumentation
* concerns
* inflection
* notifications
* time helpers
* JSON serialization helpers

### 7.6 Rails generators

Rubot should heavily use Rails generators because scaffolding is a major developer-experience advantage.

Examples:

* `rails g rubot:agent ChargebackReview`
* `rails g rubot:tool ExtractInvoiceFields`
* `rails g rubot:workflow DisputeReview`
* `rails g rubot:operator_console Disputes`
* `rails g rubot:eval DisputeReviewQuality`

## 8. Rails Gaps: What Must Be Extended for Agentic Flows

Rails has strong application primitives, but agentic workflows introduce new concerns that Rails does not solve directly.

### 8.1 Durable workflow execution

Rails jobs are useful, but Rails does not natively provide durable workflow state machines with resumable multi-step execution semantics.

Rubot must add:

* explicit workflow step definitions
* durable step checkpoints
* idempotent resumptions
* failure recovery rules
* concurrency controls per run

### 8.2 Tool protocol and safety model

Rails has service objects and POROs, but no standard concept of a typed AI-callable tool.

Rubot must add:

* tool input/output schema DSL
* execution policies
* audit metadata
* serialization for model tool-calling
* test harnesses for tools

### 8.3 Approval semantics

Rails has no built-in model for human approval checkpoints in long-running flows.

Rubot must add:

* approval steps
* role-aware approval assignment
* rejection / revision / resume paths
* approval UI components
* approval SLAs and escalation hooks

### 8.4 Agent/model interaction abstraction

Rails does not provide a standard interface for model calls, tool-calling, structured output, and retry logic.

Rubot must add:

* model adapter interface
* tool-call loop handling
* structured output enforcement
* prompt/context assembly abstraction
* token/cost usage tracking
* runtime-resolved agent properties such as instructions, model, and tools
* a middleware perimeter around agent execution for authorization, guardrails, and policy enforcement
* model-context processing hooks that shape prompts without mutating stored history

### 8.5 Event trace model

Rails instrumentation exists, but not a domain-specific trace layer for agentic execution.

Rubot must add:

* durable run events
* step-level traces
* tool invocation traces
* replay and inspection views
* correlation IDs across runs and related records

### 8.6 Evaluation primitives

Rails has tests, but no framework-native concept of evals for agent output quality.

Rubot must add:

* eval definitions
* fixtures and reference cases
* scoring hooks
* regression tracking
* optional human review for eval results

### 8.7 Operator-facing workflow components

Rails can render any UI, but agentic flows need consistent operator components.

Rubot should provide helpers or partials for:

* run timeline views
* tool call viewers
* approval panels
* confidence / warning badges
* context pack viewers
* recommended action cards

### 8.8 Subject-bound execution

In most internal tools, runs should be attached to a record or subject.

Rubot must add conventions for:

* subject association (`Customer`, `Ticket`, `Dispute`, `Invoice`)
* record-bound memories
* run permissions in subject context
* UI embedding into subject pages

### 8.9 External tool protocol integration

Rubot should support external tool ecosystems without forcing every integration to be hand-wrapped first.

Rubot must add:

* a generic client for Model Context Protocol (MCP) tool discovery and execution
* normalization from remote MCP tools into Rubot-compatible tool surfaces
* policy and audit controls so MCP-backed tools still flow through Rubot's approval, middleware, and trace model

MCP support should plug into Rubot's tool system rather than bypass it.

## 9. Architecture

### 9.1 Layers

Rubot should have five major layers.

#### Layer 1: DSL / Developer API

Defines:

* operations
* agents
* tools
* workflows
* approvals
* evals

#### Layer 2: Runtime / Orchestration

Responsible for:

* executing agents and workflows
* managing step progression
* handling tool calls
* applying memory processors to model context
* running agent middleware
* persisting state transitions
* scheduling retries and resumptions

#### Layer 3: Persistence / State

Responsible for:

* run records
* event records
* tool call logs
* approvals
* evaluations
* memory adapters

#### Layer 4: Integration

Responsible for:

* model providers
* MCP clients / remote tool adapters
* vector stores / retrieval stores
* external APIs
* authorization systems
* notification systems

#### Layer 5: Operator / Developer Experience

Responsible for:

* operation-level UI
* operator UI
* approval UI
* run inspector
* tool playground
* trace viewer
* eval dashboard

## 10. Grand Vision

Rubot's long-run shape should be:

* `Tool` as the explicit action primitive
* `Agent` as the reasoning primitive
* `Workflow` as the execution-graph primitive
* `Operation` as the top-level product and DX primitive

Small internal tools should be able to define an operation in one place, with tools, agents, workflow, and UI living together. Larger systems should be able to split those pieces apart without changing the runtime model.

Rubot should preserve a clean separation between:

* canonical run history for auditability and replay
* model context assembled for the next LLM turn

That separation enables memory processors, context compression, and tool-call filtering without losing trust or observability.

Rubot should also treat the perimeter around an agent as a first-class concern. Middleware should be the default place for:

* authorization
* prompt guardrails
* tenant or role-based tool exposure
* rate limiting
* redaction and logging

Dynamic agents should resolve key properties at runtime, especially:

* instructions
* model
* available tools

This allows operations to adapt to user role, tenant, plan tier, or subject context without collapsing into a single monolithic agent definition.

Frontend work should evolve from operator reality rather than speculation. The recommended path is:

1. Establish the runtime, approvals, provider layer, and live updates.
2. Expand the built-in operator console.
3. Introduce a true admin-panel/frontend architecture around operations.
4. Build higher-level Retool-style UI blocks on top of that foundation.

External tool ecosystems such as MCP should be supported, but only through Rubot's own safety model. Remote tools should still participate in:

* middleware
* policy checks
* approvals
* tracing
* auditability

The desired-state vocabulary for these concepts is captured in [`docs/concepts.md`](/Users/datadavis/Documents/GitHub/rubot/docs/concepts.md).

Relative to the current implementation, the major remaining gaps are:

* `Operation` as a first-class authoring and packaging primitive
* operation-level triggers for webhooks, schedules, and manual starts
* agent middleware as a runtime perimeter
* memory processors that shape model context without mutating canonical history
* dynamic runtime resolution of agent properties
* MCP-backed remote tool ingestion through Rubot's own governance model

## 11. Data Model

### 11.1 RunRecord

Fields:

* `id`
* `workflow_name` or `agent_name`
* `status` (`queued`, `running`, `waiting_for_approval`, `completed`, `failed`, `canceled`)
* `current_step`
* `subject_type`
* `subject_id`
* `input_payload` (jsonb)
* `state_payload` (jsonb)
* `output_payload` (jsonb)
* `error_payload` (jsonb)
* `started_at`
* `completed_at`
* `created_by_id` (optional)
* `correlation_id`

### 11.2 ToolCallRecord

Fields:

* `id`
* `run_record_id`
* `tool_name`
* `status`
* `input_payload` (jsonb)
* `output_payload` (jsonb)
* `error_payload` (jsonb)
* `duration_ms`
* `started_at`
* `completed_at`

### 11.3 EventRecord

Fields:

* `id`
* `run_record_id`
* `event_type`
* `step_name`
* `payload` (jsonb)
* `created_at`

### 11.4 ApprovalRecord

Fields:

* `id`
* `run_record_id`
* `step_name`
* `status` (`pending`, `approved`, `rejected`, `expired`)
* `assigned_to_type`
* `assigned_to_id`
* `role_requirement`
* `reason`
* `decision_payload` (jsonb)
* `decided_at`

### 11.5 EvaluationRecord

Fields:

* `id`
* `run_record_id`
* `eval_name`
* `score`
* `result_payload` (jsonb)
* `created_at`

## 12. DSL Specification

### 12.1 Agent DSL

Agents should support:

* `instructions`
* `tools`
* `input_schema`
* `output_schema`
* `before_run`
* `after_run`
* `policy`
* `memory`
* `middleware`

### 12.2 Tool DSL

Tools should support:

* `input_schema`
* `output_schema`
* `description`
* `policy`
* `idempotent!`
* `timeout`
* `retry_on`

### 12.3 Workflow DSL

Workflows should support:

* `step`
* `agent_step`
* `tool_step`
* `approval_step`
* `branch`
* `on_failure`
* `timeout`
* `retry`
* `resume_with`

### 12.4 Eval DSL

Evals should support:

* fixture inputs
* expected outputs or evaluators
* score functions
* threshold assertions

### 12.5 Operation DSL

Operations should eventually support:

* `workflow`
* `tools`
* `agents`
* `memory`
* `middleware`
* `ui`
* `policy`
* `fixtures`

## 13. Execution Semantics

### 12.1 Idempotency

Each step should be idempotent where possible. Rubot should record completion checkpoints so retries do not duplicate side effects.

### 12.2 Concurrency

Rubot should support subject-level locking or optimistic concurrency to avoid multiple runs mutating the same subject in conflicting ways.

### 12.3 Retry model

Rubot should distinguish:

* model/transient failures
* tool failures
* validation failures
* approval timeouts
* business-rule failures

Each class should support separate retry policy.

### 12.4 Timeouts

Workflows and steps should support deadlines, especially for operator-facing approval flows.

### 12.5 Cancellation

Runs should support cancellation by operator action or business rules.

## 14. Model Provider Layer

Rubot should define a provider-neutral adapter layer.

Responsibilities:

* send messages/prompts
* supply tool definitions to providers
* parse tool-call requests
* enforce structured outputs
* track token usage and cost metadata

Initial adapters could include:

* OpenAI adapter
* Anthropic adapter
* generic HTTP adapter

The provider layer should not leak provider-specific formats into the app-facing DSL.

MCP-backed remote tools should be normalized into Rubot's tool model rather than exposed as a parallel system.

## 15. Authorization and Policy

Rubot should integrate with app authorization systems rather than replace them.

Policy points:

* who can start a run
* who can view a run
* who can approve a step
* whether a tool may be called in a specific subject context
* whether a recommended action may be finalized automatically

Potential integration:

* Pundit
* CanCanCan
* custom policy classes

Middleware should become a first-class authorization and guardrail perimeter for agent execution.

## 16. Operator Experience

Rubot should provide a mountable operator console and embeddable view helpers.

### 16.1 Core operator views

* run index
* run detail with timeline
* approval inbox
* tool call detail
* subject-side panel
* replay view

### 16.2 Subject-side embedding

A key feature should be embedding Rubot panels into existing Rails record pages.

Examples:

* `rubot_panel @dispute`
* `rubot_timeline @ticket`
* `rubot_recommendation_card @invoice`

### 16.3 Developer playground

Rubot should include a local playground where developers can run agents or workflows against fixture records.

## 17. Evaluations and Testing

Rubot should make evals feel like a normal development primitive.

### 17.1 Unit tests

* test tool behavior
* test workflow branching logic
* test policy enforcement

### 17.2 Evals

* benchmark agent output against fixtures
* track regressions over time
* score extraction/classification/brief generation quality

Possible command:

```bash
bin/rails rubot:evals
```

## 18. Observability

Rubot observability should focus on operational trust.

Metrics:

* run counts by workflow
* completion rate
* failure rate by step
* approval wait times
* tool success/failure rate
* mean run duration
* model usage / cost

Event exports could integrate later with app observability stacks.

## 19. First-Party Tool Packs

Rubot should ship with at least one canonical first-party tool pack to demonstrate framework value.

### 19.1 File Actions tool pack

This is a strong first-party tool pack.

Tools:

* ingest file
* extract fields
* classify document
* generate brief

Why it fits:

* clearly action-oriented
* useful in finance and exception workflows
* demonstrates tool calling, structured output, and operator review patterns

## 20. Suggested Folder Structure

```txt
app/
  operations/
  agents/
  tools/
  workflows/
  rubot/
    policies/
    presenters/
    evaluators/
app/jobs/
  rubot/
app/models/
  rubot/
app/views/
  rubot/
config/
  initializers/rubot.rb
```

Small or single-purpose apps should also be able to co-locate operation definitions, tools, agents, workflow, and UI in one file before splitting them into separate folders.

## 21. V1 Milestones

### Milestone 1: Core runtime

* agent DSL
* tool DSL
* workflow DSL
* run persistence
* Active Job execution
* provider adapter interface

### Milestone 2: Approval and operator basics

* approval steps
* approval records
* run timeline UI
* simple operator console

### Milestone 3: First-party tool pack and evals

* File Actions tool pack
* eval DSL
* developer playground
* replay support

### Milestone 4: Hardening

* better concurrency semantics
* richer trace viewer
* policy integrations
* hosted control plane experiments later

## 22. Strategic Positioning

Rubot should position itself as:

* a Rails-native framework for agentic internal tools
* a way to build operator-facing AI workflows, not just bots
* a bridge between domain records and governed AI-assisted actions

The most important product distinction is that Rubot is not primarily about “chat.” It is about workflows, tools, approvals, and operator-facing software inside real applications.

## 23. Recommended Initial Tagline

Rubot is a Rails-native framework for building agentic internal tools with workflow state, approvals, and human oversight.
