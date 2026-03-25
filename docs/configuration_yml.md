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
