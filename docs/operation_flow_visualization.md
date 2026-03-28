# Operation Flow Visualization

Rubot can generate a deterministic text graph for a workflow or operation definition.

The first-pass API is:

- `MyWorkflow.flow_graph`
- `MyWorkflow.flow_mermaid`
- `MyOperation.flow_graph`
- `MyOperation.flow_mermaid`

This is definition-driven, not event-driven. It reads Rubot class metadata and step declarations rather than replaying a past run.

## What The First Version Visualizes

- operation-to-workflow structure
- triggers and named entrypoints
- workflow step ordering
- tool steps, agent steps, approval steps, and compute steps
- tool and agent class usage
- conservative data-flow edges when they are explicit and safe to infer

Examples of safe inference:

- `input: :some_step`
- `input: from_state(:some_step)`
- `input: merge(from_state(:some_step), from_context(:channel))`

Ambiguous raw lambdas are intentionally omitted from data-flow inference.

## Example

The repository includes a real multi-workflow operation at [`examples/process_ops/process_improvement_program/operation.rb`](../examples/process_ops/process_improvement_program/operation.rb).

You can render its graph with:

```ruby
require_relative "../examples/process_ops/process_improvement_program/operation"

puts ProcessOpsExamples::ProcessImprovementProgram::Operation.flow_mermaid
```

The top of the generated Mermaid output looks like:

```text
flowchart TD
  ProcessOpsExamples__ProcessImprovementProgram__Operation_operation["ProcessOpsExamples::ProcessImprovementProgram::Operation"]
  ProcessOpsExamples__ProcessImprovementProgram__Operation_trigger_manual["trigger: manual"]
  ProcessOpsExamples__ProcessImprovementProgram__Operation_trigger_future_state_design["trigger: future_state_design"]
  ProcessOpsExamples__ProcessImprovementProgram__Operation_workflow_ref_current_state["workflow: current_state"]
  ProcessOpsExamples__ProcessImprovementProgram__Operation_workflow_ref_future_state["workflow: future_state"]
```

For a smaller shape, given an operation with a default workflow and an expedited trigger:

```ruby
class ReviewOperation < Rubot::Operation
  workflow :default, ReviewWorkflow, default: true
  trigger :expedite, workflow: :default
  entrypoint :review, workflow: :default
  entrypoint :expedited_review, trigger: :expedite
end
```

You can render:

```ruby
puts ReviewOperation.flow_mermaid
```

Sample output:

```text
flowchart TD
  ReviewOperation_operation["ReviewOperation"]
  ReviewOperation_entrypoint_review["entrypoint: review"]
  ReviewOperation_trigger_expedite["trigger: expedite"]
  ReviewOperation_workflow_ref_default["workflow: default"]
```

The exact graph is generated from the operation and workflow definitions, so it stays diffable and current as the code changes.

## What Is Intentionally Omitted

- arbitrary branching semantics inside raw Ruby blocks
- runtime-only behavior discovered from event history
- data dependencies hidden inside complex lambdas
- guarantees that Rubot does not actually enforce at runtime

That omission is deliberate. The goal is a graph you can trust, not a clever diagram that overclaims.
