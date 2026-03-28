# Rubot Global YAML Configuration

Rubot supports a small global YAML config file at `config/rubot.yml`.

This file is for declarative framework-wide defaults. It does not replace Ruby authoring.

## Purpose

Use `config/rubot.yml` for:

- default provider name
- default model
- queue names
- lightweight non-executable feature flags

Keep executable behavior in Ruby.

## Supported Keys

### `provider`

String. Sets `Rubot.configuration.default_provider_name`.

Example:

```yaml
provider: openai
```

### `default_model`

String. Sets the default model when an agent does not override it.

Example:

```yaml
default_model: gpt-5-mini
```

### `queues`

Mapping. Supported keys:

- `run`
- `step`
- `resume`

Example:

```yaml
queues:
  run: default
  step: default
  resume: default
```

### `features`

Mapping for lightweight framework flags.

Current built-in flag:

- `admin_live_updates`

Example:

```yaml
features:
  admin_live_updates: false
```

## Environment Support

Rubot supports either a plain top-level config or a `default` plus environment-specific shape.

Example:

```yaml
default:
  provider: openai
  queues:
    run: default
    step: default

development:
  default_model: gpt-5-mini

production:
  default_model: gpt-5
  queues:
    run: critical
```

Merge rules:

- `default` is loaded first
- the current Rails environment overrides it
- mappings are shallow-merged
- scalar values use highest-precedence non-null value

## Precedence

Precedence is:

1. explicit Ruby config in `Rubot.configure`
2. `config/rubot.yml`
3. framework defaults

That means application initializers remain the final override point.

## Validation

Unsupported keys fail clearly during config load.

That includes:

- unknown top-level keys
- unknown queue keys
- non-mapping values for `queues` or `features`

## Rails Load Path

In Rails, Rubot loads `config/rubot.yml` automatically through the Railtie before normal app initializers run.

That makes this pattern safe and predictable:

```yaml
# config/rubot.yml
default:
  provider: openai
  default_model: gpt-5-mini
```

```ruby
# config/initializers/rubot.rb
Rubot.configure do |config|
  config.default_model = "gpt-5"
end
```

In that example, the Ruby initializer wins.

## Per-Agent YAML Configuration

Rubot agents can also load an optional YAML file that sits next to the Ruby class file.

Example:

```ruby
# app/agents/resume_screener/screening_agent.rb
module ResumeScreener
  class ScreeningAgent < Rubot::Agent
    input_schema do
      string :resume_text
    end

    output_schema do
      string :summary
    end
  end
end
```

```yaml
# app/agents/resume_screener/screening_agent.yml
instructions: |
  You are a recruiting screener.
  Review the resume against the selected role.
model: gpt-5-mini
description: Reviews resumes and returns a structured screening summary.
tags:
  - recruiting
  - screening
metadata:
  owner: talent_ops
  risk_level: medium
```

If you want a different file name, point the agent at it explicitly:

```ruby
class ScreeningAgent < Rubot::Agent
  config_file "screening_agent.config.yml"
end
```

Supported per-agent keys:

- `instructions`: string
- `model`: string
- `description`: string
- `tags`: array of strings
- `metadata`: mapping

Precedence for agent settings is:

1. explicit Ruby declarations on the agent class
2. per-agent YAML
3. global `config/rubot.yml` defaults where applicable
4. framework defaults

Notes:

- Ruby remains the source of truth for executable behavior
- per-agent YAML is only for declarative prompt and metadata values
- unsupported agent YAML keys fail during config load
