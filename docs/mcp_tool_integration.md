# MCP Tool Integration

Rubot supports MCP as a remote tool ecosystem by normalizing MCP-discovered tools into ordinary `Rubot::Tool` classes.

This means MCP tools:

- participate in the normal agent tool loop
- emit standard tool invocation and completion events
- show up in run traces, metrics, and audit records
- remain subject to middleware, dynamic tool resolution, and approval-aware workflow design

## Convenience API

Rubot provides top-level helpers for common MCP tasks:

### Discovery

```ruby
# Discover all tools on a client and register them in a namespace
tools = Rubot::MCP.discover(client, namespace: "Support")
```

### Direct Execution

```ruby
# Call an MCP tool directly without registering it first
result = Rubot::MCP.call_tool(client, "lookup_ticket", ticket_id: "123")
```

## Design Rule

MCP should enter through Rubot's tool model, not bypass it.

The implementation lives in:

- `Rubot::MCP::Client`
- `Rubot::MCP::ToolRegistry`
- `Rubot::MCP::RemoteTool`

## Example

```ruby
client = MyMCPClient.new
remote_tools = Rubot::MCP::ToolRegistry.new(client:, namespace: "SupportMCP").discover

class SupportAgent < Rubot::Agent
  tools(*remote_tools)
end
```

The discovered tools behave like normal Rubot tools from the agent's point of view.

## Safety Guidance

When exposing MCP-backed tools:

- prefer dynamic tool resolution so only the right tenants, roles, or plans get access
- treat remote tools as high-trust integrations until proven otherwise
- keep middleware enabled for authorization, redaction, and prompt/input guardrails
- avoid exposing broad write-capable remote tools to general-purpose agents by default
- use workflow approvals around sensitive actions rather than relying on the remote server alone

## Audit Semantics

MCP-backed tools emit normal Rubot tool records with extra metadata:

- `remote: true`
- `remote_protocol: "mcp"`
- `remote_tool_name`

That metadata appears in tool events and tool call records, which keeps remote execution visible in traces and metrics.

## Current Scope

The current MCP implementation provides:

- client abstraction
- remote tool discovery
- normalization into Rubot tool classes
- execution through the standard tool path

It does not yet provide:

- transport implementations for specific MCP servers
- advanced auth/session negotiation
- server capability caching or refresh policies

Those can be added later without changing the core integration model.
