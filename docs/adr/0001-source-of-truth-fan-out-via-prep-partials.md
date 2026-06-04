# Render config from one source of truth to many opt-in targets via prep partials

## Status

accepted

## Decision

Each cross-tool concept (MCP servers, agent permissions, …) is defined once as layered
`home/.chezmoidata/<area>/*.yaml` overlays and rendered into many tool-specific config files
(render targets). A source entry opts in per target explicitly (`targets.<name>.enabled: true`)
with no implicit defaults. The shared, target-independent prep — target-enablement filtering,
condition gating, and `$data.<key>` resolution — lives in one prep partial under
`home/.chezmoitemplates/` that emits JSON; each render target reads it back with `fromJson` and
only maps the eligible set to its own schema.

## Context

The same list (e.g. MCP servers) must appear in 8 tools, each with a different output schema,
across macOS, Linux, and Windows. The realistic alternatives were: hand-maintain each tool's
config (drifts immediately, no single source of truth); or render each target with its own
self-contained template (the original state — the eligibility + arg-resolution prep was
copy-pasted into every target and drifted independently). Centralising the prep behind a
JSON-emitting partial keeps one place to test and change, while leaving genuinely
target-specific shaping in each target.

## Consequences

- A reader seeing `includeTemplate "…prep…" | fromJson` should understand the partial owns the
  shared filtering/resolution; the calling template owns only schema shaping.
- Opt-in (default-off) target enablement is deliberate: adding a target to one tool must never
  silently enable it everywhere. Do not reintroduce implicit `default: true` enablement.
- ~~The per-rule conditions gate is intentionally **not** centralised for agent permissions:
  OpenCode uses a strict gate (absent condition key excludes) while Cursor/Zed use a loose gate
  (absent key includes). Only the identical collection logic is shared.~~ **Superseded by
  ADR-0002**: the strict/loose split is a one-token difference, now expressed as a `gate`
  parameter on the shared partial. The adapters no longer carry the gate loop.
- Behaviour is verified by rendering each target (`chezmoi cat` / `chezmoi execute-template`)
  and confirming byte-identical output across changes to the shared prep.
