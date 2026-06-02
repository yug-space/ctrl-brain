# Ctrl+Brain Local MCP

This server is for users who do not want Supermemory sync, or who want local AI
agents to access the same Markdown brain directly.

It runs over stdio and has no npm dependencies.

## Agent config

```json
{
  "mcpServers": {
    "ctrl-brain": {
      "command": "node",
      "args": ["/path/to/ctrl-brain/mcp/ctrl-brain-mcp.js"]
    }
  }
}
```

Default file:

```text
~/SecondBrain/captures/SecondBrain.mdx
```

Override it:

```json
{
  "mcpServers": {
    "ctrl-brain": {
      "command": "node",
      "args": ["/path/to/ctrl-brain/mcp/ctrl-brain-mcp.js"],
      "env": {
        "CTRL_BRAIN_FILE": "/Users/you/SecondBrain/captures/SecondBrain.mdx"
      }
    }
  }
}
```

## Tools

- `brain_status` - file path, size, and modified time.
- `read_brain` - full Markdown file.
- `tail_brain` - last N lines.
- `search_brain` - line search with context.
- `append_brain` - append a Markdown note from an agent.
