# Rubot

Rubot is a Rails-native framework for building agentic internal tools with durable workflow state, approvals, and operator oversight.

It gives you a small set of primitives:

- `Rubot::Tool` for explicit application actions
- `Rubot::Agent` for structured reasoning participants
- `Rubot::Workflow` for ordered, resumable orchestration
- `Rubot::Operation` for feature-level composition

Rubot is designed so product UI stays in your app, while execution logic lives in tools, agents, workflows, and operations.

## When Rubot Fits

Rubot is for production workflows, not one-off scripts.

If you just want to fetch a page and ask a model for an opinion once, a small Ruby script is usually simpler. Rubot starts to pay for itself when the process needs durable state, approvals, resumability, schema enforcement, event history, and testing seams inside a Rails app.

## Example: a tool

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

## Example: a workflow

```ruby
class AccountReviewWorkflow < Rubot::Workflow
  tool_step :lookup_account,
            tool: LookupAccount,
            input: ->(input, _state, _context) { { account_id: input[:account_id] } }

  approval_step :manager_review, role: "ops_manager"

  step :finalize

  def finalize
    run.state[:finalize] = {
      account: run.state.fetch(:lookup_account),
      decision: run.approvals.last&.decision_payload
    }
  end
end

run = Rubot.run(AccountReviewWorkflow, input: { account_id: "acct_123" })
```

## Where To Start

For setup, provider configuration, Rails integration, runtime behavior, approvals, async execution, evals, and the admin console, read the quickstart:

- [Quickstart](./docs/quickstart.md)

Useful entry points:

- [Basic workflow example](./examples/basic_workflow.rb)
- [Public API boundary](./docs/public_api.md)
- [Admin guide](./docs/admin.md)
- [Tech spec](./tech-spec.md)
