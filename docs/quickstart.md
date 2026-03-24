# Quickstart

This quickstart assumes you want the shortest path from zero to a running workflow.

## Install

Add Rubot to your Gemfile:

```ruby
gem "rubot", path: "../rubot"
```

Then require it:

```ruby
require "rubot"
```

## Build your first flow

### Tool

Tools are explicit app actions. They should look like typed service objects.

```ruby
class FetchTicket < Rubot::Tool
  description "Load ticket context for a support workflow."
  idempotent!

  input_schema do
    string :ticket_id
  end

  output_schema do
    string :ticket_id
    string :priority
    array :tags, of: :string
  end

  def call(ticket_id:)
    {
      ticket_id: ticket_id,
      priority: "normal",
      tags: ["billing"]
    }
  end
end
```

### Agent

Agents consume structured input and emit structured output. They can still be plain Ruby objects, or they can use the configured Rubot provider when you omit `perform`.

```ruby
class TriageTicketAgent < Rubot::Agent
  instructions do
    "Review ticket context and recommend routing."
  end

  model "gpt-4.1-mini"

  input_schema do
    string :ticket_id
    string :priority
    array :tags, of: :string
  end

  output_schema do
    string :queue
    string :summary
  end

end
```

Configure the provider once:

```ruby
Rubot.configure do |config|
  config.provider = Rubot::Providers::RubyLLM.new(provider_name: "openai")
  config.default_model = "gpt-4.1-mini"
end
```

### Workflow

Workflows coordinate tools, agents, and people.

```ruby
class TicketTriageWorkflow < Rubot::Workflow
  tool_step :fetch_ticket,
            tool: FetchTicket,
            input: ->(input, _state, _context) { { ticket_id: input[:ticket_id] } }

  agent_step :triage_ticket,
             agent: TriageTicketAgent,
             input: ->(_input, state, _context) { state.fetch(:fetch_ticket) }

  approval_step :supervisor_review, role: "support_supervisor"

  step :finalize

  def finalize
    run.state[:finalize] = {
      triage: run.state.fetch(:triage_ticket),
      approved_by: run.approvals.last&.decision_payload&.fetch(:approved_by, nil)
    }
  end
end
```

### Execute

```ruby
run = Rubot.run(TicketTriageWorkflow, input: { ticket_id: "t_123" })

puts run.status
# => :waiting_for_approval

run.approve!(approved_by: "lead@example.com")
Rubot::Executor.new.resume(TicketTriageWorkflow, run)

pp run.output
```

## Mental model

- `run.input` is the original payload.
- `run.state` stores step outputs by step name.
- `run.events` is the execution timeline.
- `run.approvals` holds approval records.
- `run.output` is the workflow's final state snapshot.

## Rails path

Inside a Rails app, use generators to reduce setup:

```bash
bin/rails generate rubot:install
bin/rails generate rubot:tool FetchTicket
bin/rails generate rubot:agent TriageTicket
bin/rails generate rubot:workflow TicketTriage
```

The generated classes are intentionally minimal. They are meant to be edited immediately rather than hidden behind a heavy DSL.

## Current boundaries

This quickstart is built on the in-process runtime with optional provider-backed agents. Provider-backed agents can now iterate through model responses and Rubot tool calls, while richer usage accounting and expanded operator UI are the next layers to add on top.
