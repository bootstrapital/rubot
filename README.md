# Rubot: A Ruby Framework for Workflow Engineering

Rubot is a Ruby and Rails framework for building code-first operational workflows.

It is designed for workflows that need more than a single reasoning loop: durable state, human review, replay, traceability, and a clear separation between tools, agents, workflows, and business capabilities.

Rubot is built by PDT.

## Why Rubot?

- **Durable runs**: workflow steps are checkpointed so long-running work can resume after restarts.
- **Human review**: `approval_step` lets a workflow pause for a person to approve, reject, or request changes.
- **Ruby and Rails fit**: Rubot works well inside a Rails app and follows normal Ruby application structure.
- **Traceability**: runs capture events, approvals, tool calls, and public output in one place.
- **Explicit structure**: tools handle actions, agents handle judgment, workflows handle procedure, and operations package business capabilities.

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
# Clone and bootstrap the gem development environment
bin/setup

# If you want the sample Rails app too
bin/setup --sample-app

# Or add Rubot to an existing Rails app
# Add to your Gemfile
gem 'rubot'

# Install and migrate
rails generate rubot:install
rails db:migrate
```

[View the Quickstart Guide](./docs/quickstart.md) | [Concepts](./docs/concepts.md) | [Architecture](./docs/architecture.md)
