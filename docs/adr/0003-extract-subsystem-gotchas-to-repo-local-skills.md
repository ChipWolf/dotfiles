# Extract situational subsystem gotchas from the root AGENTS.md into per-subsystem repo-local skills

## Status

accepted

Implements the Continuous-maintenance meta-rule in [`AGENTS.md`](../../AGENTS.md) (keep the
file under ~200 lines; "propose splitting into topic-specific files" when over). At decision
time the file was 269 lines.

## Decision

Move the situational, platform/app-specific subsystem guidance out of the always-on root
`AGENTS.md` into **five repo-local skills** under `.agents/skills/`, leaving the core chezmoi
knowledge and the cross-platform mechanics inline.

The five skills (one per subsystem, except that the small, provisioning-coupled Windows pieces
are bundled):

| Skill | Current `AGENTS.md` source |
|---|---|
| `finicky` | `## Finicky config changes` |
| `hammerspoon` | `## Hammerspoon (macOS Spaces)` |
| `komorebi` | `## Komorebi (Windows tiling)` |
| `mise-on-windows` | `## mise on Windows` |
| `windows-internals` | Windows-operational bullets from `## Windows support` + `## Rancher Desktop / Docker (Windows)` |

Each extracted section is replaced by a one-line `Load .agents/skills/<name>/SKILL.md before
changing <path globs>` bullet inside the existing **Repo-specific conventions** block, mirroring
the proven convention already used for `homebrew-management`, `update-mcp-servers`,
`update-agent-permissions`, and `update-skills`. The explicit file-path pointer is the always-on
discovery contract; skill `description` frontmatter carries fuzzy-match terms as a secondary
discovery path.

Three refinements that fall out of the line-level analysis:

- **The `## Windows support` section is split, not moved wholesale.** Cross-platform OS-gating
  mechanics fire on *any* new-file edit (a macOS session adding a chezmoiscript needs the
  `{{ if ne .chezmoi.os "windows" }}` guard rule) and **stay inline**. Only the
  Windows-operational internals move to `windows-internals`.
- **The mislabeled OpenCode/Atlassian bullet is removed.** It sits under "Windows support" but
  describes a *cross-platform* MCP/overlay `conditions` gate. Moving it into a Windows skill
  would hide it from macOS/Linux sessions; the behaviour is already covered by the condition-gate
  concept in [`CONTEXT.md`](../../CONTEXT.md) and the `update-mcp-servers` /
  `update-agent-permissions` skills.
- **No meta-section trigger table.** A path→skill table would cost ~10 always-on lines and create
  a second source of truth for path globs that drifts from the pointer bullets. Adopt one only if
  missed-trigger incidents are observed in practice.

## Context

The root `AGENTS.md` is auto-loaded as always-on project context for every Claude Code session
in this repo (`CLAUDE.md` → `AGENTS.md`). ~83 of its 269 lines (~31%) were situational
platform/app-specific gotchas (Windows support, Finicky, Hammerspoon, Rancher Desktop, Komorebi,
mise-on-Windows), paid for in every session regardless of relevance. The hard-won gotchas must
not be lost, only made reachable on demand.

This decision was reached by two independent `consensus`-skill panels — one seeded with candidate
options, one unseeded so the panel derived its own framing. Both converged with **no dissent**
(confidence 0.87 and 0.90) on per-subsystem repo-local skills. The unseeded panel additionally
caught the OpenCode/Atlassian mislabel and rejected the trigger-table idea.

### Options considered

- **Per-subsystem repo-local skills (chosen).** Proportional load: editing a Komorebi config
  pulls only Komorebi gotchas, not Rancher Desktop trivia. Reuses an established, zero-incident
  pattern; no new machinery.
- **Platform-grouped skills (`windows-config` / `macos-config`) — rejected.** Skill loading is
  triggered by which file the agent opens, not by an OS-session initialiser; bundling forces every
  focused edit to carry the whole platform's unrelated context.
- **Aggressive: also move core chezmoi reference into the `dotfiles` skill — rejected,
  unanimously.** Core chezmoi facts (source-state attributes, removal safety, the `modify_` JSON
  diff caveat, `.chezmoiroot` layout) are needed in essentially every session under `home/`.
  Putting them behind a skill trigger breaks the repo's primary "never guess about chezmoi"
  safety property.
- **Inline trim / status quo — rejected.** Compression recovers at most 20–30 lines, leaving the
  file over its own ceiling, and strips the incident-history "why" that makes the gotchas
  enforceable.
- **Single `subsystem-gotchas` mega-skill — rejected.** Loading all six sections to read one rule
  just moves the context-waste behind a trigger.
- **`docs/` reference files — rejected.** Markdown in `docs/` has no path-glob trigger semantics;
  ADRs are decision records, not operational gotchas.

## Consequences

- **Positive:** ~60–75 lines leave the always-on file; the file lands back under its ~200-line
  ceiling (expect ~195–210 lines once blank lines and the new pointer bullets are counted — the
  ceiling is a soft "propose splitting" trigger, not a hard limit). Focused edits load only the
  relevant subsystem. The pattern is uniform and extends to future subsystems by default.
- **Cross-reference repair:** the Finicky↔Hammerspoon auto-reload contrast (FSEvents survives
  chezmoi's atomic-rename inode swap; kqueue does not) currently relies on section adjacency. Each
  skill must restate it self-contained so it does not silently break when the sections separate.
- **Risk — pointer-path staleness:** a new subsystem file added with a non-matching name silently
  misses its skill. Mitigation: pointer path globs are enumerated explicitly (not a single
  wildcard) and updated in the **same commit** as any new subsystem file. The shared
  `run_onchange_after_bootstrap_windows.ps1.tmpl` is listed in **both** the `mise-on-windows` and
  `windows-internals` pointers.
- **Risk — skill-not-triggered:** an agent that opens a subsystem file without first reading
  `AGENTS.md` has only the pointer as discovery. This is inherent to the existing convention
  (zero reported incidents across four skills) and is partially mitigated by the "never guess"
  norm and fuzzy-match descriptions.
- **Rollback:** if a regression is ever traced to a missed skill load (e.g. an agent reintroduces
  `hs.hotkey.bind`, runs `Stop-Process -Force` on komorebi, or writes a chezmoiscript without an
  OS guard), move that subsystem's content back inline above its pointer in a single commit. No
  data loss — the skills live in the same repo.

## Dissent / minority report

None. Both consensus panels were unanimous across all rounds.
