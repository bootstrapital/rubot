# Topic-Based GEO Operation

This example shows how to model a topic-based GEO program as a Rubot operation.

The business capability is:

- build a GEO topic map from product and customer context
- turn a chosen topic into a detailed brief
- draft content at the depth of a sales conversation
- track visibility at the topic level instead of only at the prompt level

The point is not that GEO is the only valid use case. The point is that this is a good example of a workflow where:

- internal company knowledge matters
- synthesis and drafting matter
- humans still need to approve strategy and content
- the durable artifacts are more important than a single model call

## Operation Shape

`TopicBasedGeoExamples::TopicBasedGeo::Operation` packages four workflows:

- `topic_map_discovery`
- `content_brief`
- `content_draft`
- `topic_visibility_tracking`

Entry points:

- `build_strategy`
- `brief_topic`
- `draft_topic`
- `track_visibility`

## Why This Fits Rubot

This is a strong Rubot-shaped capability because:

- tools gather product, customer, and market facts
- agents synthesize and draft
- workflows sequence the work and pause for approval
- the operation presents the capability boundary

In other words, the model helps with judgment, but the workflow still behaves like software.

## Files

- `operation.rb`: operation boundary and entrypoints
- `tools/`: deterministic data loading and packaging
- `agents/`: topic strategy, briefing, drafting, and visibility analysis
- `workflows/`: the governed execution paths
- `run.rb`: small example launcher

## Suggested Next Extensions

If you wanted to take this beyond a conceptual example, the next additions would be:

- CMS draft publishing tools
- interview-transcript ingestion tools
- approval routing by role or team
- a topic snapshot store
- external visibility probes for ChatGPT / Perplexity / AI Overviews
