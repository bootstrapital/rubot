# YAML-Configured Operation Example

This example shows a small `Rubot::Operation` that uses a sibling YAML file for
agent configuration.

The agent keeps its executable behavior in Ruby, while declarative fields like
`instructions`, `model`, `description`, `tags`, and `metadata` come from
`agents/review_account_agent.yml`.

Run it with:

```bash
ruby examples/yaml_config_operation/run.rb
```
