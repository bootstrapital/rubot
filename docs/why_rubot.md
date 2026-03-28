# Why Rubot?

Rubot is a **Serious Rails Framework for Agentic Workflows**.

While many AI frameworks focus on the "Day 1" magic of LLM reasoning, Rubot is built for the "Day 2" reality of production operations.

## The "Full Iceberg" of Operational Complexity

When you build an AI agent for a real business process (like billing disputes, loan underwriting, or security triage), the LLM reasoning is only the tip of the iceberg. Under the surface lies a massive amount of required infrastructure:

1.  **Durability**: What happens if the process takes 3 days because it's waiting for a human?
2.  **Governance**: How do you ensure a VP approves any credit over $500?
3.  **Observability**: Can you audit every single tool call and LLM response 6 months later?
4.  **Resumability**: If a background job worker restarts, does the entire process start from scratch?
5.  **Rails Integration**: Does it use your existing models, policies, and jobs, or is it a separate silo?

Rubot handles all of this natively.

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

- You are building **internal tools** that leverage AI.
- Your workflows involve **high-stakes decisions** requiring human oversight.
- You need **auditability and durability** for compliance or operational stability.
- You want a **Rails-native** experience that doesn't fragment your tech stack.

[View the RevOps Comparison](../examples/compare/README.md) for a deep dive into code differences.
