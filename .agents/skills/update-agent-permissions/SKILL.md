---
name: update-agent-permissions
description: Update shared agent permission overlays and rendering for this chezmoi repo. Use when editing home/.chezmoidata/agent-permissions/*.yaml, schemas/agent-permissions.schema.json, or OpenCode permission template rendering.
---

# Update Agent Permissions

Use this skill when changing agent permission rules in this repo.

## Source of truth

- Canonical layered data: `home/.chezmoidata/agent-permissions/*.yaml`
- Schema: `schemas/agent-permissions.schema.json`
- Shared rule-collection partial: `home/.chezmoitemplates/agent-permission-rules.tmpl` (collects top-level rules + condition-enabled ruleSets once, then applies the per-rule `conditions` gate selected by the `gate` parameter; emits JSON consumed via `includeTemplate ".chezmoitemplates/agent-permission-rules.tmpl" (dict "ctx" . "gate" "strict"|"loose") | fromJson`)
- Render partials (each consumes the shared partial with its `gate` mode, then does only target-specific shaping — kind selection, matchMode expansion, destinations, `homeDir` substitution):
  - OpenCode: `home/.chezmoitemplates/opencode-permission.tmpl` (all kinds), included by `home/dot_config/opencode/modify_opencode.json`
  - Cursor: `home/.chezmoitemplates/cursor-terminal-auto-approve.tmpl` (`bash` kind only), included by `home/Library/Application Support/Cursor/User/settings.json.tmpl` and `home/AppData/Roaming/Cursor/User/settings.json.tmpl`
  - Zed: `home/.chezmoitemplates/zed-terminal-tool-permissions.tmpl` (`bash` kind only), included by `home/dot_config/zed/modify_settings.json` and `home/AppData/Roaming/Zed/modify_settings.json`

Treat `home/.chezmoidata/agent-permissions/*.yaml` as the single source of truth.

See `CONTEXT.md` (repo root) and `docs/adr/0001-source-of-truth-fan-out-via-prep-partials.md`
for the fan-out pattern, and `docs/adr/0002-parameterize-per-rule-permission-gate.md` for the
per-rule gate. The gate is centralised behind the `gate` parameter: OpenCode passes
`gate "strict"` (absent condition key excludes), Cursor/Zed pass `gate "loose"` (absent key
includes). Do not reintroduce a per-rule conditions loop in the adapters.

## Canonical schema

Rules live under:

- `agentPermissions.kinds` (map, routing and behavior per kind)
- `agentPermissions.rules` (array)

Each rule should follow this shape:

- `kind`: key from `agentPermissions.kinds`
- `pattern`: match pattern string
- `op`: `allow`, `ask`, or `deny`
- optional `conditions` object, matched against global chezmoi data
- optional `bashMatchMode` for kinds with `supportsMatchMode: true`: `exact`, `withArgs`, `exactAndWithArgs`

## Editing rules

1. Keep all permission behavior in `agentPermissions.rules` instead of introducing parallel structures.
2. Keep `agentPermissions.kinds` as the source of truth for destination routing, per-target enablement (`kinds.<kind>.targets.<target>`), and wildcard behavior, do not hardcode kind-specific destinations in templates.
3. Prefer profile-specific overlays (for example `10-<name>.yaml`) for personal/work-only rules.
4. Keep shared defaults in `00-base.yaml`.
5. Use `conditions` for environment/profile gating, not template-side hardcoded special cases.
6. Do not hand-edit generated OpenCode permission JSON, always edit data + template.

## Bash wildcard rule

OpenCode pattern matching treats bare commands and wildcard command forms distinctly in practice.

- `bashMatchMode: exact` -> emit only `"pattern"`
- `bashMatchMode: withArgs` -> emit only `"pattern *"`
- `bashMatchMode: exactAndWithArgs` -> emit both

Use `exactAndWithArgs` when both should be allowed explicitly.

## Validation workflow

After permission changes:

1. Render each affected target with current chezmoi data (`chezmoi cat <target-path>` or `chezmoi execute-template`):
   - OpenCode: `~/.config/opencode/opencode.json`
   - Cursor: `~/Library/Application Support/Cursor/User/settings.json`
   - Zed: `~/.config/zed/settings.json`
2. Confirm expected permission keys are present/absent.
3. After changing the shared `agent-permission-rules.tmpl` partial, confirm render output is byte-identical before/after for every target you can render on the current OS.
4. Run `tests/source/chezmoi.bats`.
