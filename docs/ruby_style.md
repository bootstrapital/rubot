# Ruby Style In Rubot

Rubot is a code-first Ruby framework. The library should read like Ruby written for humans, not generic generated code.

This guide is intentionally small. It captures the main idioms we want contributors and codegen to follow in `lib/rubot`.

## Core Principle

Prefer the most readable Ruby expression that preserves the runtime contract.

That usually means:

- small methods
- clear naming
- guard clauses for early exits
- explicit domain boundaries
- idiomatic Ruby defaults and collection handling

Do not force an idiom if it obscures meaning or changes behavior.

## Idioms We Prefer

### Use `||=` for memoization and default initialization

Good:

```ruby
@rubot_tools ||= []
```

Use this when `nil` means “not initialized yet.”

Do not use `||=` if `false` is a meaningful value you need to preserve.

### Prefer `unless` over `if !...`

Good:

```ruby
return unless handler
```

Avoid:

```ruby
return if !handler
```

### Use safe navigation when `nil` is expected

Good:

```ruby
run.subject_ref&.to_h
```

This is preferred over manual `nil` checks when the code is simply traversing an optional value.

### Prefer expressive collection methods

Use:

- `any?` over `!empty?`
- `one?` over `length == 1`
- `filter_map` when selecting and transforming
- `map(&:method_name)` when it is genuinely clearer

Examples:

```ruby
tool_classes.one?
selected.any?
rows.filter_map { |row| row[:value] if row[:enabled] }
```

Do not use `&:method_name` if the explicit block is easier to read.

### Use predicate methods for boolean questions

Methods returning booleans should end in `?`.

Examples already used in Rubot:

- `completed?`
- `waiting_for_approval?`
- `terminal?`

### Use implicit return by default

Reserve `return` for:

- guard clauses
- early exits
- branching that is clearer with an explicit exit

Good:

```ruby
def terminal?
  completed? || failed? || canceled?
end
```

### Use keyword arguments for public runtime APIs

Rubot’s public surface should remain explicit and self-describing.

Good:

```ruby
Rubot.run(workflow, input:, subject:, context:)
```

This is preferred over positional argument piles.

## Rubot-Specific Guidance

### Keep side effects in tools

Do not hide API calls, persistence, or file actions inside agents when they should be explicit tools.

### Keep control flow in workflows

Branching, approvals, resumability, and sequencing belong in workflows, not prompts.

### Keep operations readable

`Rubot::Operation` is the capability boundary. Favor names and defaults that make the operation legible at a glance.

### Prefer shaped runtime code over clever Ruby

Rubot is expressive, but the framework is also infrastructure. Avoid metaprogramming or compressed one-liners that make operational behavior harder to inspect.

## Linting

Rubot uses RuboCop as a lightweight enforcement layer for the library.

Run:

```bash
bundle exec rubocop lib
```

The goal is not style maximalism. The goal is to keep the framework readable, predictable, and pleasant to extend.
