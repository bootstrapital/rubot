# YAML Prompt Config and Eval Coverage Example

This example demonstrates how to manage agent prompts using external YAML files and how to test them using various eval fixture categories.

## Structure

- `agents/support_triage_agent.rb`: A Rubot agent that uses instructions from a companion YAML file.
- `agents/support_triage_agent.yml`: The prompt and model configuration for the agent.
- `agents/support_workflow.rb`: A simple workflow and operation wrapping the agent.
- `evals/support_triage_eval.rb`: A comprehensive eval suite testing the agent and the operation.

## Running the Evals

To run the evals for this example, use the Rubot CLI:

```bash
# Run all evals in this example
bundle exec rubot eval -l "examples/yaml_prompt_eval/evals/*.rb"

# Run only the Golden fixtures
bundle exec rubot eval -l "examples/yaml_prompt_eval/evals/*.rb" --tag golden

# Run the Operation-level eval
bundle exec rubot eval SupportOperationEval -l "examples/yaml_prompt_eval/evals/*.rb"
```

## Fixture Categories Demonstrated

- **Golden:** Baseline tests for standard billing and technical requests.
- **Edge-Case:** Tests for minimal input and specific logic (enterprise tier promotion).
- **Adversarial:** Tests for prompt injection resilience.
- **Dynamic:** Demonstrates generating test data at runtime.
- **Operation-Level:** Tests the full `SupportOperation` end-to-end.
