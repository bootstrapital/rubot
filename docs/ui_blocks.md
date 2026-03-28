# Rubot UI Block System

Rubot provides a set of reusable UI blocks for building admin and workbench interfaces. These blocks ensure visual consistency and provide standardized ways to display common data structures like schemas, diffs, and timelines.

## Principles

1.  **Contract-First**: Each block defines a clear set of required and optional `local_assigns`.
2.  **Primitive vs. Composed**: Primitive blocks are low-level components (e.g., a Stat, a Data Table). Composed surfaces are higher-level assemblies of primitives (e.g., a Run Overview).
3.  **Presenter-Friendly**: Blocks are designed to work well with data provided by presenters.

## Primitive Blocks

### Action Panel
Used to group related actions and their descriptions.

- **Partial**: `rubot/shared/action_panel`
- **Helper**: `rubot_action_panel(title:, meta: nil, description: nil, actions: [], &block)`
- **Contract**:
    - `title`: String. The heading of the panel.
    - `meta`: String (optional). Sub-heading or metadata.
    - `description`: String (optional). Brief description of the actions.
    - `actions`: Array of HTML strings (optional). Buttons or links.
    - `content`: HTML block (optional). Additional content.

### Data Table
A standardized table for lists of objects.

- **Partial**: `rubot/shared/data_table`
- **Helper**: `rubot_data_table(rows:, columns:, empty_title:, empty_body:)`
- **Contract**:
    - `rows`: Enumerable. The data items to display.
    - `columns`: Array of Hashes. Each hash should have:
        - `label`: String. Column header.
        - `key`: Symbol/String (optional). Method/Key to call on the row object.
        - `value`: Proc (optional). Receives the row object and returns the cell content.
    - `empty_title`: String. Title for empty state.
    - `empty_body`: String. Body for empty state.

### Detail Panel
Key-value pairs and detailed information about a single object.

- **Partial**: `rubot/shared/detail_panel`
- **Helper**: `rubot_detail_panel(title:, items: [], body: nil, badge: nil, meta: nil, badges: nil, panel_class: nil)`
- **Contract**:
    - `title`: String.
    - `items`: Array of Hashes (optional). Each hash: `{ label: "Label", value: "Value" }`.
    - `body`: HTML (optional).
    - `badge`: HTML (optional). A single badge next to the title.
    - `badges`: HTML (optional). A row of badges below the title.
    - `meta`: String (optional).
    - `panel_class`: String (optional). CSS class for the article element.

### Diff Block
Displays the difference between two payloads.

- **Partial**: `rubot/shared/diff_block`
- **Helper**: `rubot_diff_block(title:, before_value:, after_value:, meta: nil)`
- **Contract**:
    - `title`: String.
    - `before_value`: Hash.
    - `after_value`: Hash.
    - `meta`: String (optional).

### Schema Form
Renders a form based on a `Rubot::Schema`.

- **Partial**: `rubot/shared/schema_form`
- **Helper**: `rubot_schema_form(title:, schema:, url:, method: :post, values: nil, meta: nil, submit_label: "Submit")`
- **Contract**:
    - `title`: String.
    - `schema`: `Rubot::Schema`.
    - `url`: String. Form submission URL.
    - `method`: Symbol (optional). HTTP method.
    - `values`: Hash (optional). Initial values for the form.
    - `meta`: String (optional).
    - `submit_label`: String (optional).

### Schema Result
Renders a payload according to a `Rubot::Schema`.

- **Partial**: `rubot/shared/schema_result`
- **Helper**: `rubot_schema_result(title:, payload:, schema:, meta: nil)`
- **Contract**:
    - `title`: String.
    - `payload`: Hash.
    - `schema`: `Rubot::Schema`.
    - `meta`: String (optional).

### Stat
A small block for a single metric.

- **Partial**: `rubot/shared/stat`
- **Helper**: `rubot_stat(label:, value:, tone: "neutral")`
- **Contract**:
    - `label`: String.
    - `value`: String/Number.
    - `tone`: String. One of `neutral`, `info`, `warning`, `danger`, `completed`, `failed`.

### Timeline Block
A vertical list of events.

- **Partial**: `rubot/shared/timeline_block`
- **Helper**: `rubot_timeline_block(title:, events:, meta: nil)`
- **Contract**:
    - `title`: String.
    - `events`: Array of `Rubot::Event`.
    - `meta`: String (optional).

### Trace Block
A grouped view of events, typically used for debugging or detailed execution traces.

- **Partial**: `rubot/shared/trace_block`
- **Helper**: `rubot_trace_block(title:, grouped_events:)`
- **Contract**:
    - `title`: String.
    - `grouped_events`: Hash of `type => [events]`.

## Composed Admin Surfaces

These are higher-level components that combine multiple primitive blocks. They are typically found in `app/views/rubot/runs/` or other resource-specific directories.

- **Run Overview**: Uses `Detail Panel` and `Stat` blocks.
- **Trace Viewer**: Uses `Trace Block`.
- **Metrics Dashboard**: Uses `Stat` blocks.
- **Workflow Inputs**: Uses `Schema Form`.
