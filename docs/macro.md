# The MACRO Architecture

The traditional MVC (Model-View-Controller) pattern remains foundational, but it does not fully describe the shape of an agentic system. MVC was designed around short-lived request/response cycles. Agentic software introduces a different set of concerns:

- execution that may span minutes, hours, or days
- reasoning that is partly model-driven rather than purely deterministic
- human checkpoints and approvals
- durable traces of what happened and why

Rubot extends Rails into the **MACRO Architecture** as a way to talk about those additional concerns without discarding the parts of Rails that already work well.

MACRO is not meant to replace MVC. It is a companion model that explains how agentic features fit into a Rails app once execution becomes durable, inspectable, and operational.

---

## The MACRO Components

### **M — Models**
**The Skeleton.**  
ActiveRecord remains the source of truth. Models represent your core business entities (Tickets, Invoices, Customers). In a MACRO system, Models provide the data "skeleton" that Agents reason about and Tools act upon.

### **A — Agents**
**The Brain.**  
Agents are the reasoning participants. They consume structured context from your Models and use LLMs to make conclusions, classifications, or recommendations. Unlike a "service object" that follows fixed logic, an Agent handles the "fuzzy" middle where judgment is required.

### **C — Controllers**
**The Ignition.**  
Rails Controllers remain the ingress gateways. Whether it is a web form, a Twilio webhook, or a scheduled Cron job, the Controller is the "ignition switch" that validates the initial request and launches the process. In MACRO, controllers stay thin—they delegate the work to an Operation immediately.

### **R — Runs**
**The Black Box.**  
The `Run` is the most critical technical moat in Rubot. It is a durable, persistent record of execution. Unlike a stateless web request that is "forgotten" as soon as the HTML is sent, a **Run** lives in your database. It tracks every event, every tool call, and every state change. If a process fails or needs approval, the Run ensures the system can pick up exactly where it left off.

### **O — Operations**
**The Feature Boundary.**  
The `Operation` is the strategic unit of the MACRO architecture. It is the "Drawer" that packages everything together: the Triggers, the Workflow logic, the Agents, the Tools, and the UI. When you build a "Chargeback Triage" feature, you aren't just writing a script; you are defining an **Operation**—a sellable, auditable business capability.

---

## The Philosophy

MACRO is useful because agentic systems create pressure in places that MVC alone does not name clearly.

### 1. Requests are not the whole story

In a conventional Rails app, the request is often the dominant unit of work. A controller receives params, coordinates some logic, and returns a response. That remains true for the app surface, but it stops being the whole picture once work can pause, resume, await approval, call external tools, or branch over time.

MACRO introduces the `Run` as the durable unit of execution so the system has memory outside the request cycle.

### 2. Not all important logic is deterministic

Rails conventions are very good at deterministic business logic: validations, callbacks, service objects, queries, policies, and transactions. Agentic systems add a second kind of logic: reasoning under uncertainty.

That logic should not leak everywhere. MACRO keeps it explicit by giving reasoning a dedicated home in `Agents`, while still keeping concrete actions explicit in tools and workflow steps.

### 3. Operational systems need explicit traces

Logs are not enough for agentic features that affect business processes. Teams need to know:

- what input was used
- what the model concluded
- which tools were called
- where a human approved or rejected
- where a run paused or failed

MACRO centers `Runs` because durable, inspectable execution is the difference between an operational system and a prompt glued into a controller.

### 4. Human oversight is part of the architecture

In many real workflows, the goal is not full autonomy. The goal is well-structured assistance that can be reviewed, approved, corrected, and replayed. That means human-in-the-loop behavior is not an exception case; it is part of the design.

MACRO assumes that pauses, approvals, escalations, and operator review are normal parts of the system.

### 5. Rails remains the host

MACRO should not be read as “replace Rails with an AI framework.” The opposite is closer to the truth. Rails still owns:

- models
- controllers
- routes
- rendering
- auth
- persistence
- jobs

MACRO describes how to extend that system once you need durable reasoning and operational workflows. It preserves Rails as the host architecture and adds clearer names for the new moving parts.

## Why MACRO?

| Feature | Legacy MVC | MACRO Architecture |
| :--- | :--- | :--- |
| **Persistence** | Stateless; forgotten after request | Durable; state saved in **Runs** |
| **Logic** | Deterministic; "If/Else" | Reasoning-based; **Agents** |
| **Workflow** | Short-lived; synchronous | Long-running; asynchronous |
| **Safety** | Immediate; no "Pause" | Guarded; **Approvals** & Human-in-the-loop |
| **Auditability** | Logs (hard to parse) | **Traces** (structured history) |

---

## The Strategic Shift

The MACRO architecture shifts the developer's focus from **"responding to a request"** to **"designing a durable unit of work."**

By treating the **Run** and the **Operation** as first-class citizens, you avoid burying agentic behavior inside controllers, background jobs, or prompts with no durable record. The result is a system that can be inspected, governed, and improved over time.

In practice, MACRO helps teams build systems that are:

- more explicit about where reasoning lives
- safer to operate because execution can pause and be reviewed
- easier to debug because traces and runs are first-class
- easier to evolve because feature boundaries stay visible

The point is not to make Rails feel less like Rails. The point is to give Rails developers a more accurate mental model for software that reasons, acts, and persists work over time.
