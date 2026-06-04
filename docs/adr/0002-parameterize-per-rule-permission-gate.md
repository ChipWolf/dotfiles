# Parameterize the per-rule permission gate in the shared prep partial

## Status

accepted

Supersedes the "per-rule conditions gate is intentionally not centralised" consequence of
[ADR-0001](0001-source-of-truth-fan-out-via-prep-partials.md).

## Decision

The per-rule `conditions` gate for agent permissions lives in the shared prep partial
`home/.chezmoitemplates/agent-permission-rules.tmpl` behind an optional `gate` parameter:

- `gate: "strict"` — an absent condition key excludes the rule (OpenCode). A rule matches only
  when every condition key is present in chezmoi data and equals the expected value.
- `gate: "loose"` — an absent condition key includes the rule (Cursor, Zed). A rule is excluded
  only when the key is present and differs.
- omitted — no per-rule gating; rules pass through (the prior collection-only behavior).

Each render adapter requests its mode (`(dict "ctx" . "gate" "strict")` etc.) and consumes the
already-gated eligible set. The adapters keep only genuinely target-specific shaping: kind
selection, matchMode expansion, namespaced vs top-level destinations, and `homeDir`
substitution.

## Context

ADR-0001 left the gate in each adapter because the strict and loose variants differ. In
practice the difference is a single comparison (`eq` vs `ne`) on the absent-key branch, while
the surrounding collect-and-iterate loop was copy-pasted into all three adapters
(opencode-permission, cursor-terminal-auto-approve, zed-terminal-tool-permissions). That made
the gate a shallow duplicated module: the loop reappeared three times to express one boolean of
real variation. Folding the gate into the partial as a `gate` parameter concentrates the
filtering logic in one place (locality) behind a one-word interface (leverage), and turns the
strict/loose choice into data rather than copied control flow.

## Consequences

- The strict/loose semantics now have one definition and one place to test. The adapters carry
  no `conditions` loop.
- The `gate` parameter is opt-in: omitting it preserves collection-only behavior, so any future
  consumer that wants to gate itself still can.
- Verified by rendering each permission target (`chezmoi cat` of OpenCode/Zed/Cursor settings)
  byte-identical before and after, plus a synthetic test covering present-match, present-mismatch,
  absent-key, and no-condition rules under both gate modes.
