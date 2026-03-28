# Prompt Management and Regression Workflow

In Rubot, prompts are treated as code. Changes to prompts are behavioral changes, and they must be managed with the same rigor as any other part of your application.

## Per-Agent YAML vs Inline Ruby

Rubot allows you to define agent instructions (prompts) and other configurations (model, tags, etc.) either in your Ruby class or in a companion YAML file.

### When to use YAML:
- **Large Prompts:** When your instructions are several paragraphs long.
- **Frequent Updates:** If you need to tweak the prompt often without modifying application logic.
- **Multi-Model Testing:** When you want to swap models easily for experiments.
- **Collaboration:** If non-engineers need to edit prompts.

**Usage:**
Create a `.yml` file with the same name as your `.rb` file (e.g., `triage_agent.yml` next to `triage_agent.rb`).

```yaml
# triage_agent.yml
instructions: |
  You are a triage agent.
  Categorize the incoming request into 'billing', 'technical', or 'other'.
model: gpt-4o
tags: ["core", "v2"]
```

### When to use Inline Ruby:
- **Simple Prompts:** One or two sentences.
- **Dynamic Prompts:** When your instructions depend on complex runtime logic or calculated values.
- **Single Source of Truth:** If you prefer keeping everything in one file for simplicity.

```ruby
class TriageAgent < Rubot::Agent
  instructions "Triage the request into categories."
  model "gpt-4o"
end
```

## Prompt Versioning in Git

- **Atomic Commits:** Always commit your prompt changes together with the code that depends on them.
- **Meaningful Commit Messages:** Describe *why* the prompt was changed (e.g., "Adjust instructions to reduce billing category false positives").
- **Branching:** Use feature branches for prompt experimentation and only merge to main after passing evals.

## Pairing Changes with Evals

A prompt change is incomplete without running and potentially updating the associated eval suite.

1. **Modify Prompt:** Update the YAML or Ruby file.
2. **Run Evals:** Execute `bundle exec rubot eval <YourAgent>`.
3. **Analyze Failures:** If your prompt change broke existing "Golden" fixtures, investigate why.
4. **Update Fixtures:** If the behavior change was intentional, update the `expected` values in your eval fixtures.
5. **Add New Fixtures:** If the prompt change was to address a specific issue (e.g., a new edge case), add a corresponding fixture to prevent regression.

## Prompt/Output Guardrails

Rubot provides several layers of protection to ensure prompt integrity and output quality:

### 1. Middleware
Middleware can pre-process inputs or post-process model outputs. This is ideal for:
- **Input Sanitization:** Removing PII or harmful tokens before sending to the model.
- **Output Validation:** Manually checking for certain forbidden patterns in the model's response.

### 2. Policy
Policies provide structural guardrails. They ensure that the agent only has access to allowed tools or information based on the current context.

### 3. Evals
Evals act as the final quality gate. They don't block the run in production, but they prevent "low-quality" code/prompts from being deployed by failing in CI.

## Recommended Lifecycle

1. **Research:** Identify a need for a prompt change.
2. **Experiment:** Modify the prompt and run against the current eval suite.
3. **Strategy:** If current evals pass but don't cover the new behavior, add new fixtures.
4. **Execution:** Finalize the prompt and its associated evals.
5. **Validation:** Run the full eval suite one last time before committing.
6. **Deployment:** The CI pipeline runs `rubot eval` as a final gate before deployment.
