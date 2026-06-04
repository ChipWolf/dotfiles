# MCP Servers (How To)

MCP server configuration follows the same layered-data pattern as Brew.

Source files:

- `home/.chezmoidata/mcps/*.yaml` (canonical overlays, merged lexically)
- schema: `schemas/mcp-servers.schema.json`

Shared prep partial (single source of the filtering + `$data.*` resolution; see
[CONTEXT.md](../CONTEXT.md) and [ADR-0001](adr/0001-source-of-truth-fan-out-via-prep-partials.md)):

- `home/.chezmoitemplates/mcp-eligible-servers.tmpl` — emits the eligible server set per target as JSON

Render targets (each consumes the prep partial via `includeTemplate ... | fromJson`, then maps to its own schema):

- Cursor via `home/dot_cursor/mcp.json.tmpl`
- OpenCode via `home/dot_config/opencode/modify_opencode.json` (partial `home/.chezmoitemplates/opencode-mcp.jsonc.tmpl`)
- pi via `home/dot_pi/agent/mcp.json.tmpl`
- Zed (Unix) via `home/dot_config/zed/modify_settings.json` (partial `home/.chezmoitemplates/zed-context-servers.tmpl`)
- Zed (Windows) via `home/AppData/Roaming/Zed/modify_settings.json` (same partial)
- Claude Code via `home/modify_dot_claude.json`
- Claude Desktop (Windows) via `home/AppData/Roaming/Claude/modify_claude_desktop_config.json`
- mcpproxy via `home/private_dot_mcpproxy/modify_mcp_config.json`

## Data shape

Each overlay contributes to:

```yaml
mcp:
  serversById:
    <server-id>:
      enabled: true
      local: ... # or remote: ...
```

`serversById` is a map keyed by server id. This enables clean layered overrides across multiple YAML files.

## Quick start

### Add a remote server

```yaml
mcp:
  serversById:
    context7:
      enabled: true
      remote:
        url: "https://mcp.context7.com/mcp"
```

### Add a local server

```yaml
mcp:
  serversById:
    obsidian:
      enabled: true
      local:
        command: "mise"
        args:
          - "x"
          - "node@22"
          - "--"
          - "npx"
          - "-y"
          - "@mauricio.wolff/mcp-obsidian@0.8.2"
          - "$data.obsidianVaultPath"
        env: {}
```

## Common tasks

### Disable a server

```yaml
mcp:
  serversById:
    atlassian:
      enabled: false
```

### Enable a server for one client only

Targets are **opt-in**: a server renders to a target only when it explicitly sets
`targets.<name>.enabled: true`. Unlisted targets get nothing, so to scope a server to a
single client list only that client:

```yaml
mcp:
  serversById:
    mcp-atlassian:
      enabled: true
      targets:
        cursor:
          enabled: true
```

### Show a server only on certain machines

Use `conditions` against global chezmoi data (for example from `home/.chezmoi.toml.tmpl`):

```yaml
conditions:
  private: false
```

### Interpolate data values in args

Use `$data.<key>` in `local.args`; template rendering replaces tokens inline.

## Field reference

Per-server fields under `mcp.serversById.<id>`:

- `enabled` (required)
- `conditions` (optional)
- `targets` (optional, **opt-in**). Each target defaults to `false`; a server renders to a
  target only when that target sets `enabled: true`. Unlisted targets render nothing.
- `targets.<name>.enabled` for `name` in: `cursor`, `opencode`, `pi`, `zed`, `claudeCode`,
  `claudeDesktop`, `mcpproxy` (optional, default `false`)
- exactly one of `local` or `remote`

`local` fields:

- `command` (required)
- `args` (required)
- `env` (optional)

`remote` fields:

- `url` (required)
- `transport` (optional)
- `headers` (optional)

## Validation

1. Render each target with `chezmoi cat <target-path>` (or `chezmoi execute-template`) and
   confirm valid JSON with the expected servers and resolved `$data.*` args.
2. After changing the shared prep partial, confirm render output is byte-identical for the
   targets you can render on the current OS (`chezmoi cat` before/after).
3. Run `pre-commit run --all-files` (on Windows run via WSL in this repo).

See `.agents/skills/update-mcp-servers/SKILL.md` for the full validation workflow.
