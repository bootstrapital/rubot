# Rubot: Serious Rails Framework for Agentic Workflows

Rubot is a Rails-native framework for building durable, governed, and observable AI workflows.

While other AI frameworks focus on simple reasoning loops, Rubot is built for the "Full Iceberg" of production operations—handling the 80% of enterprise logic that involves waiting for humans, persisting through restarts, and providing an auditable event trail.

## Why Rubot?

- **Durable by Default**: Every workflow step is checkpointed. If a worker restarts, the process resumes exactly where it left off.
- **Human-in-the-Loop**: Native `approval_step` support allows workflows to pause for hours or days while waiting for a human decision.
- **Rails-Native**: Seamlessly integrates with ActiveRecord, ActiveJob, and ActionController. No new infrastructure silos.
- **Observable**: Every tool call, model response, and state change is captured in a durable `Run` record.
- **Deterministic Visualization**: Generate Mermaid diagrams directly from your Ruby code to see your business logic in real-time.

[Read more: Why Rubot?](./docs/why_rubot.md)

## RevOps Comparison

See how Rubot compares to "Raw" Rails, Mastra (TS), and LangGraph (Python) in a real-world billing dispute scenario:

[View Comparison Table](./examples/compare/README.md)

## Core Primitives

- **Operations**: The business capability boundary (e.g., `UnderwritingOperation`).
- **Workflows**: The durable procedure (sequencing, approvals, retries).
- **Agents**: The reasoning participants (LLM-driven logic).
- **Tools**: The application actions (calling APIs, querying DBs).
- **Runs**: The durable unit of execution.

## Example

```ruby
class AccountReviewWorkflow < Rubot::Workflow
  tool_step :lookup_account,
            tool: LookupAccount,
            input: from_input(:account_id)

  approval_step :manager_review, 
                role: "ops_manager",
                reason: "Human review required for high-value accounts."
                
  output :lookup_account
end

# Run synchronously or async
run = Rubot.run(AccountReviewWorkflow, input: { account_id: "acct_123" })
```

## Getting Started

```bash
# Add to your Gemfile
gem 'rubot'

# Install and migrate
rails generate rubot:install
rails db:migrate
```

[View the Quickstart Guide](./docs/quickstart.md) | [Concepts](./docs/concepts.md) | [Architecture](./docs/architecture.md)
