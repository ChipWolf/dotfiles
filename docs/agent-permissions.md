# Agent Permissions (How To)

Agent permission rules are managed as layered chezmoi data, then rendered into several editors'
configs.

Source files:

- `home/.chezmoidata/agent-permissions/*.yaml` (overlays merged lexically)
- schema: `schemas/agent-permissions.schema.json`

Shared prep partial (collects the top-level rules + condition-enabled ruleSets once; see
[CONTEXT.md](../CONTEXT.md) and [ADR-0001](adr/0001-source-of-truth-fan-out-via-prep-partials.md)):

- `home/.chezmoitemplates/agent-permission-rules.tmpl` — emits the collected rule list as JSON

Render targets (each consumes the prep partial, keeps its own per-rule conditions gate + shaping):

- OpenCode via `home/dot_config/opencode/modify_opencode.json` (partial `home/.chezmoitemplates/opencode-permission.tmpl`) — honours all `kinds`
- Cursor via `home/Library/Application Support/Cursor/User/settings.json.tmpl` and `home/AppData/Roaming/Cursor/User/settings.json.tmpl` (partial `home/.chezmoitemplates/cursor-terminal-auto-approve.tmpl`) — `bash` kind only
- Zed via `home/dot_config/zed/modify_settings.json` and `home/AppData/Roaming/Zed/modify_settings.json` (partial `home/.chezmoitemplates/zed-terminal-tool-permissions.tmpl`) — `bash` kind only

A `kind` renders to a target only when `agentPermissions.kinds.<kind>.targets.<target>` is
truthy (e.g. `bash` enables `opencode` and `zed`; `external_directory` and `permission_key`
enable `opencode` only).

## Data shape

Each overlay contributes to:

```yaml
agentPermissions:
  kinds:
    bash:
      destinationType: namespaced
      destinationKey: bash
      targets:
        opencode: true
        zed: true
      supportsMatchMode: true
      defaultMatchMode: exact
      wildcardSuffix: " *"
    external_directory:
      destinationType: namespaced
      destinationKey: external_directory
      targets:
        opencode: true
    permission_key:
      destinationType: top_level
      targets:
        opencode: true
  rules:
    - kind: bash
      pattern: "git status"
      op: allow
      bashMatchMode: exactAndWithArgs
```

All rule types share the same schema. Kind routing is data-driven via `agentPermissions.kinds`.

## Kind configuration

`agentPermissions.kinds` controls where each rule kind is rendered:

- `destinationType: namespaced` -> rule emits into `permission.<destinationKey>`
- `destinationType: top_level` -> rule emits at top level of `permission`
- `targets.<target>` -> per-target enablement for the kind (truthy = rendered to that target)
- `supportsMatchMode` + `defaultMatchMode` + `wildcardSuffix` control wildcard expansion behavior for that kind

Note: the per-rule `conditions` gate is applied inside each render target, not in the shared
prep partial — OpenCode uses a strict gate (an absent condition key excludes the rule) while
Cursor/Zed use a loose gate (an absent key includes it). Both agree for the conditions used in
this repo (`ci`, `private`), which are always present.

Rules then reference a configured kind by `kind`.

## Rule fields

Supported rule fields:

- `kind` (required): key from `agentPermissions.kinds`
- `pattern` (required): match string
- `op` (required): `allow`, `ask`, or `deny`
- `conditions` (optional): key/value match against template data (for example `private: false`)
- `bashMatchMode` (optional, `kind: bash` only): `exact`, `withArgs`, or `exactAndWithArgs`

## Rule kinds

### `bash`

Generates entries inside `"permission"."bash"`.

`bashMatchMode` controls exact and wildcard emission:

- `exact` -> `"pattern"`
- `withArgs` -> `"pattern *"`
- `exactAndWithArgs` -> both keys

This exists because OpenCode glob matching does not treat `"cmd *"` as equivalent to bare `"cmd"` for all cases.

### `external_directory`

Generates entries inside `"permission"."external_directory"`:

```yaml
- kind: external_directory
  pattern: "~/.local/share/chezmoi/**"
  op: allow
```

### `permission_key`

Generates top-level permission keys (same level as `bash`/`external_directory`), useful for MCP tool patterns:

```yaml
- kind: permission_key
  pattern: "atlassian_*"
  op: ask
  conditions:
    private: false
```

## Overlay strategy

Use the same split pattern as Brew and MCP:

- `00-base.yaml`: shared defaults
- `10-<profile>.yaml`: personal/work/fork-specific rules

In this repo, Atlassian-specific permission keys live in `home/.chezmoidata/agent-permissions/10-chipwolf.yaml`.

## Validation

1. Render each target (`chezmoi cat <target-path>` or `chezmoi execute-template`) and confirm
   expected permission keys are present/absent.
2. After changing the shared prep partial, confirm render output is byte-identical for the
   OpenCode, Cursor, and Zed settings targets (`chezmoi cat` before/after).
3. Run test suite (`tests/source/chezmoi.bats`).
4. Run `pre-commit run --all-files` before commit.

See `.agents/skills/update-agent-permissions/SKILL.md` for the full validation workflow.

