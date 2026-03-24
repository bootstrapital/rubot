# Sample Rubot App

This is a minimal Rails host app for previewing the Rubot engine locally and demonstrating a Rubot-powered Rails app with visible `app/tools`, `app/agents`, `app/workflows`, and `app/operations`.

## What it includes

- mounts `Rubot::Engine` at `/rubot/admin`
- serves an operations home page at `/`
- serves the resume screener operation at `/ops/resume_screener`
- uses `Rubot::Stores::ActiveRecordStore`
- composes the feature across:
  - [`app/operations/resume_screener/operation.rb`](./app/operations/resume_screener/operation.rb)
  - [`app/tools/resume_screener/load_job_description_tool.rb`](./app/tools/resume_screener/load_job_description_tool.rb)
  - [`app/tools/resume_screener/prepare_resume_tool.rb`](./app/tools/resume_screener/prepare_resume_tool.rb)
  - [`app/agents/resume_screener/screening_agent.rb`](./app/agents/resume_screener/screening_agent.rb)
  - [`app/workflows/resume_screener/workflow.rb`](./app/workflows/resume_screener/workflow.rb)

## Run it

Because this environment has both macOS system Ruby and Ruby 3.3 installed, use the explicit Ruby 3.3 binary when launching Rails:

```bash
cd sample_app
/Users/datadavis/.rvm/rubies/ruby-3.3.0/bin/ruby -S bundle exec rails server
```

Then open:

```text
http://localhost:3000
```

Useful routes:

- `/`
- `/ops/resume_screener`
- `/rubot/admin`
- `/rubot/admin/dashboard`
- `/rubot/admin/playground`
- `/rubot/admin/runs`
- `/rubot/admin/approvals`

## Gemini Configuration

The demo works without an API key using a heuristic fallback scorer.

To enable LLM-backed screening with RubyLLM and Gemini, set:

```bash
export GEMINI_API_KEY=your_key_here
export RUBOT_MODEL=gemini-3-flash-preview
```

Then restart the Rails server.

The current configuration lives in [`config/initializers/rubot.rb`](./config/initializers/rubot.rb). It will:

- configure `RubyLLM` with `config.gemini_api_key = ENV["GEMINI_API_KEY"]`
- configure Rubot to use [`Rubot::Providers::RubyLLM`](../lib/rubot/providers/ruby_llm.rb) with provider `"gemini"`
- default the model to `gemini-3-flash-preview` unless `RUBOT_MODEL` is overridden
- persist runs, approvals, events, and tool calls into the sample app database
