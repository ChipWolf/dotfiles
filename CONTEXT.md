# chezmoi dotfiles — context

This repo defines config that `chezmoi apply` writes into the home directory. Most of its
non-trivial complexity is one shape repeated: a single layered data source is rendered into
many tool-specific config files, each with its own output schema. This glossary fixes the
language for that machinery so it reads as one pattern, not many bespoke templates.

For architecture vocabulary (module, interface, seam, adapter, depth), see
`~/.agents/skills/improve-codebase-architecture/LANGUAGE.md`. This file covers the
project-specific domain only.

## Language

**Source of truth**:
The layered `home/.chezmoidata/<area>/*.yaml` data that defines a concept once — MCP servers,
agent permissions, brew packages, registry keys, and so on. Every render target derives from
it; nothing is hand-maintained per target.
_Avoid_: config, master list, canonical data

**Overlay**:
A single numbered data file within an area (e.g. `00-base.yaml`, `10-chipwolf.yaml`). chezmoi
merges overlays in lexical name order: base overlays hold shared defaults, higher-numbered
overlays add or override per fork/machine.
_Avoid_: layer, profile, variant

**Render target**:
One tool's generated config file (Cursor, OpenCode, pi, Zed, Claude Code, Claude Desktop,
mcpproxy, …). A target consumes the source of truth and emits it in that tool's own schema.
_Avoid_: client, consumer, destination, rendered output

**Target enablement**:
The opt-in flag a source entry sets per target (`targets.<name>.enabled: true`). An entry
renders to a target only when it explicitly opts in; an unlisted target gets nothing. There
are no implicit defaults — intent is always visible in the YAML.
_Avoid_: toggle, flag, opt

**Condition gate**:
An optional `conditions` map on a source entry (or ruleSet) matched against chezmoi data
(e.g. `private: false`, `ci: false`). The entry renders only when every condition matches the
current machine.
_Avoid_: filter, guard, predicate

**Prep partial**:
A shared `home/.chezmoitemplates/*.tmpl` that does the target-independent prep once —
target-enablement and condition gating, plus value resolution — and emits JSON that render
targets read back with `fromJson`. The single place that shared work lives. Current prep
partials: `mcp-eligible-servers.tmpl`, `agent-permission-rules.tmpl` (collection plus the
optional strict/loose per-rule `gate`, see ADR-0002), `overlay-flatten.tmpl` (sortAlpha
overlay walk + list concat for chocolatey/winget/registry), and `modify-stdin.tmpl` (the
stdin-into-merged-dict preamble every `modify_` template shares).
_Avoid_: helper, include, mixin

**Eligible set**:
The output of a prep partial: the source entries that survive target enablement and condition
gating, with placeholders already resolved. A render target maps the eligible set to its
schema and does nothing else shared.
_Avoid_: filtered list, results

**Data interpolation**:
The `$data.<key>` token allowed in `local.args`. A prep partial replaces it in place with the
matching chezmoi data value (e.g. `$data.obsidianVaultPath`). Resolution happens once, in the
prep partial, never per target.
_Avoid_: variable, placeholder substitution
