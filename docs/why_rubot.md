# Why Rubot?

Rubot is a Ruby and Rails framework for building code-first operational workflows.

It is most useful when a workflow has to survive real operating conditions: waiting for people, preserving state, recording decisions, and staying understandable after the first version ships.

## Operational Work Needs More Than A Prompt Loop

When you build workflow software for a real business process like billing disputes, underwriting, or security triage, the reasoning step is only one part of the system. The rest usually includes:

1.  **Durability**: What happens if the process takes 3 days because it's waiting for a human?
2.  **Governance**: How do you ensure a VP approves any credit over $500?
3.  **Observability**: Can you audit every single tool call and LLM response 6 months later?
4.  **Resumability**: If a background job worker restarts, does the entire process start from scratch?
5.  **Application fit**: Does it use your existing models, policies, and jobs, or does it become a separate silo?

Rubot gives those concerns an explicit home in the framework.

## Rubot vs. The World

| Feature | Rubot | Typical "Agent" Script | LangGraph / Mastra |
| :--- | :--- | :--- | :--- |
| **Persistence** | Native (Rails DB) | None | Manual / Extra Infra |
| **Human-in-the-loop** | First-class `approval_step` | Hard-coded | Complex Interrupts |
| **Observability** | Full Event/Trace Log | `puts` statements | Variable |
| **Rails-Native** | Yes (Engine/Job/Record) | No | No |

## The Core Unit of Work: The `Run`

In a standard web app, the **Request** is the primary unit of work. In Rubot, it is the **Run**.

A `Run` is a durable, stateful, and observable record of an operation's execution. It persists through restarts, pauses for human decisions, and provides a complete audit trail of every interaction.

## When to use Rubot

- You are building workflow software around a business process, not just a one-off script.
- Your workflows involve human review, approvals, or long-running state.
- You need auditability and durability for operational stability or compliance.
- You want a Ruby or Rails implementation that does not fragment your application stack.

[View the RevOps Comparison](../examples/compare/README.md) for a deep dive into code differences.
