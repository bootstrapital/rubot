# Process Ops Examples

These examples are a precursor to a future PDT library.

They are intentionally shaped like framework examples rather than standalone Ruby scripts. Each capability is split into an `operation`, `workflow`, `agent`, and `tool` so the examples look more like a future installable operation library.

Included examples:

- `sipoc/`: high-level process scoping with a SIPOC draft and review step
- `process_mapping/`: current-state process mapping with stages, handoffs, and exception paths
- `bottleneck_analysis/`: bottleneck analysis based on stage metrics and operational observations
- `process_improvement_program/`: advanced example showing one operation packaging shared tools and agents across multiple related workflows

Directory shape:

```text
examples/process_ops/
  sipoc/
    operation.rb
    workflow.rb
    agents/
    tools/
  process_mapping/
    operation.rb
    workflow.rb
    agents/
    tools/
  bottleneck_analysis/
    operation.rb
    workflow.rb
    agents/
    tools/
```

The examples are meant to be read as authoring references for Rubot and as seeds for a future PDT operation catalog.

## Why Operations Matter Here

The simple examples can look redundant if an operation only points at a single workflow. That is a fair read of the current API.

Today, `Rubot::Operation` is most useful as:

- a feature boundary
- a packaging boundary
- a trigger and launch boundary
- a place to group shared workflows, tools, and agents under one capability

The advanced `process_improvement_program/` example is meant to show that value more clearly. It packages:

- one shared tool
- two related agents
- two related workflows
- one default workflow for normal launch
- one alternate workflow addressed by name or trigger

The current `Operation` API now supports both:

- inline named workflows for small features
- separately defined named workflows for larger features

That gives operations a clearer role as the feature boundary above one or more workflows, rather than just a thin wrapper around a single runnable.
