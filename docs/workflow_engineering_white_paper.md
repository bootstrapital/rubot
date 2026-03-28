# Workflow Engineering

This document is an attempt to formalize an approach that has been emerging in practice.

The most useful analogy is the rise of dbt and analytics engineering.

dbt did not invent SQL or the data warehouse. It made a discipline legible by giving people a shaped environment for building durable systems on top of an existing substrate.

Workflow engineering is a similar idea applied to operational software.

The short version is:

- more operational software will be authored through code generation
- many of the people specifying that software will sit closer to operations than to traditional product engineering
- the main challenge is no longer "can a model produce code?"
- the main challenge will be "can the resulting system be trusted, reviewed, governed, and maintained?"

This paper uses `workflow engineering` to describe that discipline: the practice of building code-first operational workflows that remain structured enough to trust, review, govern, and maintain.

It also describes why the framework and runtime layer matter, why AI should be treated as a component rather than the category itself, and why a system like PDT is aimed at a different problem than general-purpose agent platforms.

## Why This Needs A Name

Many important business processes now sit in an awkward middle ground.

They are too complex and too risky to leave as:

- spreadsheets
- email chains
- Slack channels
- checklists in document tools
- GUI automation recipes
- scattered internal scripts

But they are also too specific and too operational to receive the same level of engineering investment as customer-facing product features.

Historically, this gap has been filled with a mix of:

- Excel macros
- low-code tools
- workflow builders
- internal tools platforms
- one-off software written by a small number of technical operators or accommodating engineers

Each of those solved part of the problem. None solved the full problem.

Code generation changes the economics again. It is becoming much easier to produce custom software around a specific operational process. That shift creates a new opportunity, but it also creates a new failure mode: organizations can now produce brittle workflow code much faster than before.

Workflow engineering is a way to describe the response to that problem.

In that sense, it is less like inventing a new kind of software than like making an existing kind of work legible enough to become a discipline.

## What Workflow Engineering Is

Workflow engineering is the practice of building operational software that coordinates:

- systems
- humans
- policy
- approvals
- state
- evaluation
- AI where useful

The unit of work is not a page, endpoint, or standalone script. It is an operational capability.

Examples include:

- dispute handling
- refund review
- intake and routing
- lead qualification handoff
- case investigation
- compliance review
- process mapping
- escalation management

The core concern is not just automating a task. It is building a reliable system for doing a recurring kind of work.

That means workflow engineering is concerned with:

- how work enters the system
- what facts are gathered
- where judgment is applied
- which actions are allowed
- when human review is required
- what state is preserved
- how the system is inspected later
- how changes are validated before they are trusted

## What Workflow Engineering Is Not

It is not simply:

- prompt engineering
- agent orchestration
- business process modeling
- no-code automation
- internal tools development in general

Those areas overlap with workflow engineering, but none is the same thing.

Prompt engineering focuses on one component of model behavior. Workflow engineering treats model behavior as one element inside a broader operational system.

Agent orchestration focuses on coordinating model-driven actors. Workflow engineering focuses on the business procedure, the side-effect boundaries, the human review model, and the long-term ownership of the software.

Business process modeling tends to stop at description. Workflow engineering continues to implementation, runtime behavior, and maintenance.

No-code automation tends to optimize for access and speed. Workflow engineering is more concerned with whether the resulting system is explicit enough to be trusted and owned over time.

## Why Now

Workflow engineering matters now because three shifts are converging, and the interaction between them changes the economics of operational software.

### 1. Code Generation Has Lowered The Cost Of Bespoke Software

A team no longer needs the same amount of engineering labor to build a capability-specific workflow system. Coding agents can draft much of the implementation if the target architecture is legible enough.

That does not eliminate the need for engineering. It changes where engineering effort is applied.

The effort shifts toward:

- architecture
- boundaries
- review
- governance
- evaluation
- integration

### 2. Operational Work Is Already Software-Shaped

Many operational functions now sit on top of:

- SaaS systems of record
- APIs
- tickets
- files
- approvals
- policy checks
- internal casework

This work already behaves like software, even when organizations still manage it through manual coordination.

### 3. The Existing Tools Stop Short Of Durable Software

GUI workflow tools are useful, but they often hide logic, diffuse ownership, and make iterative change harder than expected.

One-off software gives more control, but it often lacks shared conventions for state, approval, replay, and governance.

Model vendors can now generate and execute code, but that still does not solve the architectural problem by itself.

The important point is not any one of these trends in isolation. It is their convergence.

Operational work is increasingly system-mediated. The old implementation surfaces are reaching their limits. At the same moment, custom software has become much cheaper to produce.

That creates both an opportunity and a risk.

The opportunity is that more operational work can become real software.

The risk is that organizations can now produce brittle workflow code much faster than before.

## The Historical Lineage

Workflow engineering did not appear out of nowhere. It sits in a line of older patterns.

### Excel Macros

Excel macros gave business users a way to express procedure inside the tool where work already lived.

The strengths were:

- immediate leverage
- closeness to the problem
- low activation energy

The weaknesses were:

- weak structure
- poor visibility
- fragile maintenance
- limited system boundaries

That general instinct remains important: people close to the work want a way to shape the software that supports the work.

### Internal Tools And Low-Code Platforms

Internal tools platforms made it easier to build task-specific interfaces and admin workflows. They improved speed and accessibility, but often struggled with:

- long-lived logic ownership
- explicit execution semantics
- replayability
- structured evaluation
- complex approval-driven flows

### Analytics Engineering

The rise of dbt and analytics engineering is a useful analogy.

dbt did not invent SQL or the data warehouse. It helped make a new discipline legible by giving analysts and analytics engineers a shaped environment for building durable data systems.

Workflow engineering may represent a similar step for operational systems:

- the people closest to the business process can increasingly shape the implementation
- code generation reduces the distance between intent and execution
- a framework is needed to make the output structured enough to keep

The analogy is not perfect, but it is useful.

If Rails is analogous to SQL in this comparison, the missing "warehouse" equivalent is not another programming language. It is a shared operational state and control layer: runs, cases, approvals, events, checkpoints, history, and machine-facing control surfaces.

That is why the runtime matters so much.

## The Role Of AI

AI should be treated as a component of workflow engineering, not the category itself.

That distinction matters for both product design and category durability.

AI is useful for:

- classification
- summarization
- extraction
- recommendation
- normalization
- drafting
- anomaly explanation
- routing suggestions

But an operational workflow is not reducible to model output.

Someone still has to decide:

- what data the model sees
- what action the model is allowed to propose
- whether a proposal can trigger a side effect directly
- when approval is required
- how the output is validated
- how failures are handled
- how the process is inspected later

As model quality improves, this distinction becomes more important, not less.

Better models reduce the cost of producing behavior. They do not remove the need for:

- architecture
- governance
- state management
- review
- regression control

In the same way that internet, mobile, and SaaS eventually became assumed layers rather than category headlines, AI is likely to become a capability layer that strong systems incorporate rather than the sole organizing idea.

## The Core Design Problem

The central design problem in workflow engineering is:

how to let software use probabilistic judgment without allowing the entire operational system to become probabilistic and ungoverned.

That requires explicit boundaries.

The most useful boundary model is usually some version of this:

- tools gather or change facts
- agents produce structured judgment
- workflows control procedure and policy
- operations package the business capability
- runs preserve durable execution history

These boundaries matter because they prevent a workflow from collapsing into a single opaque loop.

## A Practical Architecture

Different frameworks will implement this differently, but the functional layers are consistent.

### Capability Layer

A business capability should be the top-level unit of organization.

Examples:

- refund review
- dispute resolution
- vendor onboarding assessment
- sales handoff qualification

This layer answers:

- what kind of work is this?
- what entrypoints exist?
- which procedures belong to it?

### Procedure Layer

The procedure layer defines:

- steps
- order
- approval points
- resumability
- state transitions

This is the workflow proper.

### Action Layer

The action layer defines explicit side-effect and retrieval boundaries.

Typical actions:

- load a record
- call an external API
- parse a document
- update a system
- emit a notification

This layer should be concrete and inspectable.

### Judgment Layer

This is where model-backed behavior fits.

Typical roles:

- summarize
- classify
- recommend
- extract
- draft

The important part is not that this layer exists. The important part is that it does not silently swallow the rest of the architecture.

### Runtime Layer

The runtime layer preserves:

- runs
- events
- approvals
- checkpoints
- outputs
- trace history

This is part of what makes workflow engineering different from prompt scripts or thin agent harnesses.

### Control Layer

Over time, a serious workflow engineering system also needs:

- API access
- CLI access
- machine-readable evaluation reports
- machine-to-machine launch and governance

That control layer is the counterpart to the growing need for workflows to be driven by other systems, not only by interactive app users.

## Why A Framework Layer Matters

The main reason a framework like PDT exists is not convenience. It is to preserve shape.

Code generation works best when the target has:

- a clear file layout
- repeatable naming
- stable entrypoints
- explicit extension points
- durable runtime semantics

Without that, generated software tends to become a patchwork of service objects, direct API calls, prompts, and hidden state transitions.

That can work for a demo. It tends not to hold up when:

- more people touch it
- policies change
- approvals are required
- failures need to be explained
- the organization depends on it daily

## Prompt Management And Evaluation

Prompt management should be treated as part of operational software maintenance.

That means:

- prompts should usually live in versioned files
- prompt changes should be reviewed like behavior changes
- important workflows should have fixture-based evaluation
- drift cases should accumulate after incidents and regressions

The practical point is simple: if model behavior influences routing, recommendations, extraction, or approvals, then prompt changes are not merely copy changes.

They are workflow changes.

A reasonable evaluation discipline includes:

- golden fixtures for common cases
- edge-case fixtures for ambiguous or risky cases
- adversarial fixtures for injection or policy evasion
- drift fixtures for previously broken behavior
- thresholded scores where exact string matching is too brittle

This is one of the places where AI must be treated as a component inside a system rather than the entire system.

## Human Review Is Not A Temporary Crutch

Many operational systems will continue to require human review even as models improve.

That is not necessarily a sign of immaturity.

In many businesses, review exists because:

- policy is contextual
- risk is asymmetric
- external consequences are real
- accountability matters

Workflow engineering should therefore treat approvals, assignments, and review surfaces as first-class parts of the architecture, not as awkward exceptions to a fully autonomous ideal.

## Why This Is Different From Agent Platforms

Agent platforms are often organized around:

- model calls
- tool use
- loops
- multi-agent coordination
- deployment of agent-driven tasks

Those are useful primitives, but they do not fully address the workflow engineering problem.

Workflow engineering is more concerned with:

- business capability boundaries
- explicit procedures
- side-effect control
- approvals
- replay
- durable state
- evaluation against operational outcomes
- maintainable code-first workflow systems

The difference is not that agent platforms are wrong. The difference is that their center of gravity is different.

If the center of gravity is "operating AI agents," the architecture often bends around the agent.

If the center of gravity is "building operational software," the architecture bends around the workflow and the business capability.

That distinction becomes more visible as systems mature.

## Why Model Vendors Do Not Obviate This Layer

A reasonable objection is that model vendors will keep improving their models, harnesses, tool use, desktop execution, and coding support. Why would a separate workflow engineering layer still matter?

The answer is that improvements in intelligence do not eliminate the need for a system architecture.

Model vendors can improve:

- code generation
- task execution
- local automation
- tool invocation

That makes workflow engineering more feasible. It does not remove the need for:

- explicit capabilities
- durable state
- approvals
- replay
- policy boundaries
- structured evaluation
- organizational ownership

Put differently:

- the model vendor can improve the worker
- workflow engineering defines the factory

If software generation becomes cheaper, the demand for a strong ownership layer should increase rather than decline.

## Who This Is For

The most likely early practitioners already exist today, just under different titles.

Titles that already overlap heavily with this work include:

- RevOps Systems Manager
- RevOps Process and Systems Manager
- RevOps Systems Architecture lead
- Business Systems Manager
- Sales Operations Manager
- Operations Engineer

Many of these roles are effectively SaaS administrators today.

They configure and govern functional SaaS systems such as:

- Salesforce
- HubSpot
- Zendesk
- NetSuite
- internal admin and ticketing systems

They own:

- fields and schemas
- permissions
- routing rules
- approvals
- automations
- reports
- integrations
- process enforcement

These roles already sit near the right problems:

- designing and maintaining workflows
- managing approvals and exceptions
- connecting systems of record
- improving process quality and data quality
- translating business requirements into system behavior
- introducing automation without losing control

What they often lack is a clearer software architecture and runtime model for the workflows they are being asked to build.

The shift is from administering SaaS workflows to building bespoke operational layers on top of SaaS systems.

That is why `workflow engineer` is best understood first as a convergence role, not a purely new invention.

The key function is: someone close enough to the work to model it accurately, and technical enough to shape the software that runs it.

That person will usually not come from a traditional software engineering background.

In practice, the role emerges at the boundary between:

- operations
- systems thinking
- process design
- business systems ownership
- software engineering

In some organizations, workflow engineering may become a distinct title. In others, it may describe how an existing RevOps, business systems, operations, or internal tools role evolves as code generation lowers the cost of building bespoke operational software.

This is similar to how analytics engineering moved data teams away from only operating the enterprise data stack and toward building bespoke transformation layers on top of the warehouse with dbt.

Workflow engineering applies the same pattern to operations:

- SaaS systems remain the systems of record
- the workflow layer becomes company-specific software
- the practitioner moves from package administration toward software-defined operations

Code generation lowers the activation energy for that role. A framework and runtime make it more plausible for the resulting workflow systems to remain coherent.

## What Good Adoption Looks Like

A healthy adoption pattern usually starts small.

### Start With One Capability

Choose a workflow that is:

- painful enough to matter
- narrow enough to finish
- risky enough that governance matters
- repetitive enough that structure will pay off

### Make The Boundaries Explicit

Define:

- where facts come from
- where judgment happens
- which side effects are allowed
- where review is required
- what output the workflow must produce

### Add Evaluation Early

Do not wait until later to accumulate fixture-based checks for important model behavior.

### Keep The UI Separate From The Runtime

The product UI that launches work is not the same thing as the operator surface that inspects, approves, and replays work.

### Treat The First Workflow As A Template For Ownership

The first capability should establish the conventions that later generated capabilities will follow.

## A Simple Test

A useful test for whether something belongs in the workflow engineering category is this:

if the model were swapped out tomorrow, would the system still have a meaningful architecture?

If the answer is yes, and the architecture still includes:

- explicit procedures
- durable state
- side-effect boundaries
- approval and review semantics
- evaluation and history

then the system is likely operating at the workflow engineering layer.

If the answer is no, and most of the value collapses into "the model did a task," then it is probably still closer to an agent integration than to workflow engineering.

## Conclusion

Workflow engineering is a useful name for an emerging practical discipline.

It is about building operational software in a world where:

- code generation is widespread
- AI is a normal component
- more builders sit close to operations
- organizations still need structure, review, and maintenance

The point is not to make software creation look magical.

The point is to make it easier for recurring operational work to become real software without losing the properties that make software worth relying on in the first place.
