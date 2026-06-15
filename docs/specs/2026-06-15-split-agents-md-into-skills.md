# Design spec: split the root AGENTS.md subsystem gotchas into repo-local skills

Date: 2026-06-15
Decision record: [ADR-0003](../adr/0003-extract-subsystem-gotchas-to-repo-local-skills.md)
Status: approved, ready for implementation

This is the implementation map for ADR-0003. It is exact down to the line because the value of
the change is entirely in *not losing* any hard-won gotcha while moving it off the always-on path.

## Goal

Reduce the always-on context cost of the root [`AGENTS.md`](../../AGENTS.md) (269 lines, over its
own ~200-line ceiling) by moving situational platform/app-specific subsystem guidance into five
repo-local skills under `.agents/skills/`, while keeping core chezmoi knowledge and cross-platform
mechanics inline. `.agents/` is outside the chezmoi source state (`.chezmoiroot=home`), so these
files have zero `chezmoi apply` impact.

## The five skills

Each skill is `/.agents/skills/<name>/SKILL.md` with `name` + `description` frontmatter (matching
the `homebrew-management` shape), then a body of: a **Scope** line listing the trigger path globs,
followed by the gotchas moved verbatim from `AGENTS.md`.

`description` must include the listed fuzzy-match terms so a complaint-driven debugging session
(one that never opens the config file) can still surface the skill via search.

### 1. `finicky` (macOS)
- **Source:** `## Finicky config changes` (AGENTS.md lines 196–204), moved verbatim.
- **Scope / trigger globs:** `home/dot_config/finicky.js.tmpl` (target `~/.config/finicky.js`).
- **Description terms:** Finicky, browser router, auto-reload, inode, kqueue, fsnotify, restart
  required, macOS.
- **Special requirement:** restate the auto-reload contrast self-contained — "Finicky's kqueue
  watcher tracks by inode and loses the watch when chezmoi replaces the file with a new inode on
  every write; a manual restart is always required (unlike Hammerspoon's FSEvents path watcher)."
  Drops the dependence on the old "see Hammerspoon" adjacency.

### 2. `hammerspoon` (macOS)
- **Source:** `## Hammerspoon (macOS Spaces)` (lines 208–216), moved verbatim.
- **Scope / trigger globs:** `home/dot_hammerspoon/*` (`init.lua`, `spaces.lua`).
- **Description terms:** Hammerspoon, macOS Spaces, Space switching, eventtap, hotkey.bind,
  Ctrl+1, Mission Control, Carbon hotkey reservation, hs.spaces, hs.ipc, Accessibility.
- **Special requirement:** rewrite line 214 ("Auto-reload works, unlike Finicky above") to be
  self-contained — "`hs.pathwatcher` uses FSEvents (path-based) and survives chezmoi's
  atomic-rename writes (new inode each apply), unlike Finicky's inode-based kqueue watcher."

### 3. `komorebi` (Windows)
- **Source:** `## Komorebi (Windows tiling)` (lines 233–247), moved verbatim.
- **Scope / trigger globs:** `home/dot_config/komorebi/*`, `home/dot_config/whkdrc`.
- **Description terms:** Komorebi, Windows tiling WM, whkd, KOMOREBI_CONFIG_HOME, Stop-Process,
  sock file, AF_UNIX, layered_applications, FancyZones, reload-configuration.

### 4. `mise-on-windows` (Windows)
- **Source:** `## mise on Windows` (lines 251–257), moved verbatim.
- **Scope / trigger globs:** `home/.chezmoitemplates/windows-mise-shim-placement.ps1.tmpl`,
  `home/.chezmoiscripts/run_after_97_mise_shim_windows.ps1.tmpl`, and the mise-relevant portion of
  `home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl` (**shared** with
  `windows-internals`).
- **Description terms:** mise Windows, mise-shim.exe, binary path, file shim mode, MCP servers,
  cannot find binary path, Chocolatey mise, reshim, PS 5.1 stderr, claude-code-win32.

### 5. `windows-internals` (Windows)
- **Source:** the Windows-operational bullets carved out of `## Windows support` (see migration
  table below) **plus** the whole `## Rancher Desktop / Docker (Windows)` section (lines 220–229),
  moved verbatim.
- **Scope / trigger globs (enumerate explicitly, not a single wildcard):**
  - `home/.chezmoiscripts/*windows*.ps1.tmpl` (excluding the mise-shim scripts owned by
    `mise-on-windows`)
  - `home/.chezmoiscripts/run_after_96_rancher_desktop_windows.ps1.tmpl`
  - `home/.chezmoidata/wsl/`
  - `home/.chezmoidata/ssh-tpm-agent.yaml`
  - `home/.chezmoidata/ssh-signing.yaml`
  - `home/private_dot_ssh/allowed_signers.tmpl`
  - `home/.chezmoitemplates/wsl-*.tmpl`
  - `home/dot_config/wezterm/`
- **Description terms:** Windows internals, WSL, cloud-init, rsync --delete, Rancher Desktop, moby,
  rdctl, Docker daemon pipe, ssh-tpm-agent, TPM, two gpg.exe, WezTerm, Windows bootstrap,
  elevation, YASB.
- **Special requirements:**
  - Preserve the ordering note explicitly in prose: Rancher Desktop (`run_after_96_…`) runs
    **after** WSL ensure (`run_after_95_…`) so Ubuntu exists for integration.
  - The bootstrap script `run_onchange_after_bootstrap_windows.ps1.tmpl` is shared; list it here
    *and* in `mise-on-windows`.

## Windows support section: line-by-line migration

The `## Windows support` section (lines 157–171) is split, not moved wholesale.

| Line | Content | Disposition |
|---|---|---|
| 159 | "Native Windows" deploy/skip overview | **Stay inline** (condense to a one-liner in conventions) |
| 160 | OS-conditional `.chezmoiignore` syntax | **Stay inline** — fires on any new-target edit |
| 161 | Bash chezmoiscript `{{ if ne … "windows" }}` guard | **Stay inline** — fires on any new chezmoiscript |
| 162 | Windows bootstrap | **Split:** keep a one-liner that chocolatey/winget package lists live in `home/.chezmoidata/{chocolatey,winget}/*.yaml` as `overlays.<name>.packages` (brew-style merge); move CI/YASB/elevated-block/`windows-elevation.ps1.tmpl` mechanics → `windows-internals` |
| 163 | `install.ps1.tmpl` description | **Fold** into the existing "Install script templates" bullet (line 150), which already covers `install.ps1.tmpl`; delete the duplicate |
| 164 | WezTerm | **Move** → `windows-internals` |
| 165 | ssh-tpm-agent | **Move** → `windows-internals` |
| 166 | OpenCode/Atlassian `conditions` gating | **Delete** — mislabeled cross-platform MCP gating; covered by the condition-gate concept (CONTEXT.md) + `update-mcp-servers`/`update-agent-permissions` |
| 167 | "Package manager — Windows uses Chocolatey" | **Stay inline** as a conventions one-liner |
| 168 | Two `gpg.exe` on Windows | **Move** → `windows-internals` |
| 169 | "When adding new configs…" decide cross/unix/windows | **Stay inline** — cross-platform rule |
| 170 | "When adding new chezmoiscripts…" OS guards | **Stay inline** — cross-platform rule |
| 171 | WSL provisioning | **Move** → `windows-internals` |

The inline survivors (159–161, 167, 169–170, plus the package-list and install-template one-liners)
are relocated into the **Repo-specific conventions** block as conventions-index bullets; the
`## Windows support` heading is removed.

## AGENTS.md pointer bullets

Add these to the **Repo-specific conventions** block, following the existing format. Place the
macOS pointers near the (updated) "Other config" bullet and the Windows pointers clustered
together near the Windows conventions one-liners — not dumped at the end of the block.

```
- **Finicky** – Load `.agents/skills/finicky/SKILL.md` before changing the Finicky config (`home/dot_config/finicky.js.tmpl`).
- **Hammerspoon (macOS Spaces)** – Load `.agents/skills/hammerspoon/SKILL.md` before changing `home/dot_hammerspoon/*`.
- **Komorebi (Windows tiling)** – Load `.agents/skills/komorebi/SKILL.md` before changing `home/dot_config/komorebi/*` or `home/dot_config/whkdrc`.
- **mise on Windows** – Load `.agents/skills/mise-on-windows/SKILL.md` before changing `home/.chezmoitemplates/windows-mise-shim-placement.ps1.tmpl`, `home/.chezmoiscripts/run_after_97_mise_shim_windows.ps1.tmpl`, or the mise parts of `home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl`.
- **Windows internals** – Load `.agents/skills/windows-internals/SKILL.md` before changing Windows-operational scripts/data: `home/.chezmoiscripts/*windows*.ps1.tmpl`, `home/.chezmoidata/wsl/`, `home/.chezmoidata/ssh-tpm-agent.yaml`, `home/.chezmoidata/ssh-signing.yaml`, `home/private_dot_ssh/allowed_signers.tmpl`, `home/.chezmoitemplates/wsl-*.tmpl`, `home/dot_config/wezterm/`.
```

## Other inline cleanups

- **Line 145 "Other config":** drop the `finicky` mention so the `finicky` skill pointer is the
  single source of truth. (Leaves "tmux, mise" + the gnupg note.)
- **Line 163:** delete (folded into the install-script-templates bullet).
- **Line 166:** delete (mislabeled, see migration table).
- **Continuous-maintenance meta-rule:** add a line — new platform/app-specific subsystem gotchas
  go into a `.agents/skills/<name>/` skill with an inline pointer, not inline prose.

## Verification

1. **No content lost:** diff each deleted section against the new SKILL.md; every bullet appears
   in exactly one skill (verbatim or with the self-contained auto-reload rewrite).
2. **Cross-platform rules still inline:** confirm lines 160, 161, 169, 170 (and equivalents) remain
   in `AGENTS.md`.
3. **Line count:** `wc -l AGENTS.md` lands in ~195–210 (target: under the soft ~200 ceiling). If it
   exceeds ~215, audit for residual situational content rather than re-extracting OS-gating rules.
4. **Trigger spot-check:** a session opening `home/dot_hammerspoon/spaces.lua` matches the
   Hammerspoon pointer but **not** the Finicky or Komorebi pointers.
5. **Skill discovery:** the five new skills appear in the agent's available-skills list (same as
   the existing `homebrew-management`).
6. **Glob coverage cross-check:** walk the file tree and confirm every moved subsystem's real files
   are covered by a pointer glob (especially `home/.chezmoitemplates/wsl-*.tmpl` and
   `home/.chezmoidata/ssh-signing.yaml`).
7. **No chezmoi impact:** `chezmoi diff` is unaffected by the `.agents/` additions.

## Out of scope

- The global `home/dot_agents/AGENTS.md` (→ `~/.agents/AGENTS.md`) — different file, not touched.
- Distributing these skills to other agents via the `vercel-labs/skills` CLI — repo-local skills
  are read in place per-repo; only the repo-root `skills/` tree is distributed.
- A meta-section path→skill trigger table (explicitly rejected; revisit only on observed
  missed-trigger incidents).
