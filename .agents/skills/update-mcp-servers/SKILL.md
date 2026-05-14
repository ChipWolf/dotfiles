---
name: update-mcp-servers
description: Update canonical MCP server definitions for this chezmoi repo and template rendering checks. Use when editing home/.chezmoidata/mcps/*.yaml, Cursor MCP template output, or OpenCode MCP config generation.
---

# Update MCP Servers

Use this skill when changing MCP server configuration in this repo.

## Source of truth

- Canonical layered data: `home/.chezmoidata/mcps/*.yaml`
- Cursor render template: `home/dot_cursor/mcp.json.tmpl`
- OpenCode render template: `home/dot_config/opencode/opencode.jsonc.tmpl` (via `home/.chezmoitemplates/opencode-mcp.jsonc.tmpl`)
- mcpproxy render template: `home/private_dot_mcpproxy/modify_mcp_config.json`
- pi render template: `home/dot_pi/agent/mcp.json.tmpl`
- Claude Code render template: `home/modify_dot_claude.json` (merges `mcpServers` into `~/.claude.json`)
- Claude Desktop render template: `home/AppData/Roaming/Claude/modify_claude_desktop_config.json`
- Zed render template (Unix): `home/dot_config/zed/settings.json.tmpl` (via `home/.chezmoitemplates/zed-context-servers.tmpl`)
- Zed render template (Windows): `home/AppData/Roaming/Zed/modify_settings.json.tmpl`

Treat `home/.chezmoidata/mcps/*.yaml` as the single source of truth.

## Canonical schema

Each entry in `mcp.serversById.<id>` should follow this shape:

- `enabled`
- optional `conditions` object, each key/value is matched against global chezmoi data
- optional `targets.opencode.enabled` (defaults to **`false`** — opt-in)
- optional `targets.cursor.enabled` (defaults to **`false`** — opt-in)
- optional `targets.mcpproxy.enabled` (defaults to **`false`** — opt-in)
- optional `targets.pi.enabled` (defaults to **`false`** — opt-in)
- optional `targets.claudeDesktop.enabled` (defaults to **`false`** — opt-in; Windows Claude desktop app)
- optional `targets.claudeCode.enabled` (defaults to **`false`** — opt-in; Claude Code CLI `~/.claude.json`)
- optional `targets.zed.enabled` (defaults to **`false`** — opt-in; Zed context servers)

Every server must explicitly list each target it should render to. Targets not listed render to nothing for that server. This avoids hidden defaults and makes intent obvious in the YAML.

Each server must define either `local` or `remote` (not both).

Local shape:

- `local.command` string
- `local.args` array
- optional `local.env`
- args can include `$data.<key>` tokens to interpolate global chezmoi data values in-place

Remote shape:

- `remote.url`
- optional `remote.transport`
- optional `remote.headers`

## Editing rules

1. Keep a single canonical `local` or `remote` config per server.
2. Keep transport configuration at server level, use `targets` only for enablement.
3. Do not re-introduce duplicate fields like parallel `cursorLocal` and `local`.
4. Keep command execution via `mise` where applicable.
5. Use layered map overrides in separate files under `home/.chezmoidata/mcps/` when personal/fork-specific behavior is needed.

## Validation workflow

After MCP changes:

1. Render `home/dot_cursor/mcp.json.tmpl` with current chezmoi data.
2. Render `home/dot_config/opencode/opencode.jsonc.tmpl` with current chezmoi data.
3. Render `home/private_dot_mcpproxy/modify_mcp_config.json` with current chezmoi data.
4. Render `home/dot_pi/agent/mcp.json.tmpl` with current chezmoi data.
5. Render `home/modify_dot_claude.json` with stdin `{}` and current chezmoi data (merged JSON must parse).
6. Render `home/AppData/Roaming/Claude/modify_claude_desktop_config.json` with stdin `{}` and current chezmoi data.
7. Render `home/dot_config/zed/settings.json.tmpl` with current chezmoi data.
8. Render `home/AppData/Roaming/Zed/modify_settings.json.tmpl` with stdin `{}` and current chezmoi data.
9. Validate the rendered Cursor, mcpproxy, pi, Claude Code, Claude Desktop, and Zed outputs are valid JSON.
10. Confirm expected server entries and args in rendered output, including `$data.*` interpolation.

Note: sprig `hasPrefix` signature is `hasPrefix prefix str`. The `$data.<key>` interpolation must be written as `hasPrefix "$data." $arg`, not the reverse.

Templates should trust schema-required fields. Use `hasKey` checks only for optional fields.
