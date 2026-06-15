# Extract AGENTS.md subsystem gotchas into repo-local skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the six situational platform/app-specific sections out of the always-on root `AGENTS.md` into five repo-local skills under `.agents/skills/`, replacing each with a one-line pointer, so focused sessions stop paying for irrelevant subsystem context.

**Architecture:** Five new `SKILL.md` files (`finicky`, `hammerspoon`, `komorebi`, `mise-on-windows`, `windows-internals`) hold the gotchas verbatim. `AGENTS.md` keeps core chezmoi knowledge and cross-platform mechanics inline, and gains a `Load .agents/skills/<name>/SKILL.md before changing <globs>` pointer per subsystem in the Repo-specific conventions block. `.agents/` is outside the chezmoi source state (`.chezmoiroot=home`), so this has zero `chezmoi apply` impact.

**Tech Stack:** chezmoi, Markdown, repo-local agent skills. No build/test runner — verification is grep/diff/`wc -l`.

---

## Pre-flight (already done)

- Branch `refactor/extract-subsystem-skills` exists and is checked out.
- [ADR-0003](../adr/0003-extract-subsystem-gotchas-to-repo-local-skills.md) and the [spec](../specs/2026-06-15-split-agents-md-into-skills.md) are committed (`7c07b03`).
- Line numbers below refer to `AGENTS.md` at that commit. Verify with `grep -n '^## ' AGENTS.md` before starting.

Confirm state:

```bash
git branch --show-current   # refactor/extract-subsystem-skills
grep -n '^## ' AGENTS.md    # Finicky=196, Hammerspoon=208, Rancher=220, Komorebi=233, mise=251, Windows support=157
```

---

## Task 1: Create the `finicky` skill

**Files:**
- Create: `.agents/skills/finicky/SKILL.md`

The body is the `## Finicky config changes` section (AGENTS.md 198–204) verbatim. Its auto-reload paragraph is already self-contained (no reference to Hammerspoon), so no rewrite is needed.

- [ ] **Step 1: Write the file**

```markdown
---
name: finicky
description: Finicky browser-router config for this chezmoi repo (macOS). Covers the mandatory restart-after-apply procedure and why Finicky's auto-reload fails under chezmoi. Triggers — Finicky, browser router, auto-reload, inode, kqueue, fsnotify, restart required. Load before changing home/dot_config/finicky.js.tmpl.
---

# Finicky (macOS)

**Scope:** `home/dot_config/finicky.js.tmpl` (target `~/.config/finicky.js`).

After applying changes to the Finicky config (`~/.config/finicky.js`), reload it by:

1. `killall Finicky || true`
2. `open -a Finicky`
3. Close the foreground window manually (AppleScript window close is not available without assistive access)

Finicky's built-in auto-reload does NOT work when the config is managed by chezmoi. Chezmoi replaces the file with a new inode on every write; Finicky's fsnotify watcher (kqueue on macOS) tracks by inode and loses the watch when this happens. A restart is always required.
```

- [ ] **Step 2: Verify frontmatter and body**

Run: `head -3 .agents/skills/finicky/SKILL.md && grep -c 'killall Finicky' .agents/skills/finicky/SKILL.md`
Expected: frontmatter `name: finicky`; count `1`.

- [ ] **Step 3: Commit**

```bash
git add .agents/skills/finicky/SKILL.md
git commit -m "feat(skills): add finicky skill (extracted from AGENTS.md)"
```

---

## Task 2: Create the `hammerspoon` skill

**Files:**
- Create: `.agents/skills/hammerspoon/SKILL.md`

Body is the `## Hammerspoon (macOS Spaces)` section (210–216) verbatim, EXCEPT the auto-reload bullet (line 214 "Auto-reload works, unlike Finicky above") is rewritten self-contained, since the Finicky section now lives in a separate file.

- [ ] **Step 1: Write the file**

```markdown
---
name: hammerspoon
description: Hammerspoon macOS Space-switching config for this chezmoi repo. Covers eventtap-vs-hotkey.bind, full-screen spaces, Accessibility, and debugging via the hs CLI. Triggers — Hammerspoon, macOS Spaces, Space switching, eventtap, hotkey.bind, Ctrl+1, Mission Control, Carbon hotkey reservation, hs.spaces, hs.ipc, Accessibility. Load before changing home/dot_hammerspoon/*.
---

# Hammerspoon (macOS Spaces)

**Scope:** `home/dot_hammerspoon/init.lua`, `home/dot_hammerspoon/spaces.lua` (→ `~/.hammerspoon/`).

Hammerspoon provides direct macOS Space switching: `⌃1`–`⌃5` jump to the Nth Space on the focused screen, including full-screen-app spaces. Cask in `home/.chezmoidata/brew/00-base.yaml` (macOS-gated); config at `home/dot_hammerspoon/{init.lua,spaces.lua}` (→ `~/.hammerspoon/`), gated to darwin in `home/.chezmoiignore`. Gotchas that have bitten us:

- **Use `hs.eventtap`, not `hs.hotkey.bind`, for `⌃`+number Space switches.** macOS reserves `⌃1`..`⌃N` as Carbon hotkeys for "Switch to Desktop" based on the number of Mission Control *user* desktops, even when the System Settings "Switch to Desktop" checkboxes are off. `RegisterEventHotKey` then rejects those combos: `hs.hotkey:enable()` returns nil and the console logs `-9878 ... already registered`, so `hs.hotkey.bind` silently fails for the low-numbered keys (for example `⌃1`/`⌃2` when two desktops exist) while higher ones bind fine. An event tap reads the keystroke from the event stream before hotkey dispatch and is not subject to the reservation. Diagnose with `hs -c 'return #hs.hotkey.getHotkeys()'` (binds missing) plus the Hammerspoon console.
- **`hs.spaces` reaches full-screen spaces.** `hs.spaces.spacesForScreen(uuid)` lists every Space (user and full screen/tiled, per `hs.spaces.spaceType`) in Mission Control order, and `hs.spaces.gotoSpace(id)` activates one by driving its Mission Control thumbnail, so it can land on full-screen spaces (the native `⌃`+number shortcuts cannot). Map "Space N" by indexing that list by position.
- **Auto-reload works.** `hs.pathwatcher` uses FSEvents (path-based), so it survives chezmoi's atomic-rename writes (new inode each apply). By contrast, Finicky's `fsnotify`/kqueue watcher is inode-based and loses the watch on every chezmoi write, so Finicky needs a manual restart (see the `finicky` skill).
- **`hs.ipc` is enabled** in `init.lua`, so the running config is queryable from the `hs` CLI (`hs -c '...'`), the main way to debug Spaces and hotkeys.
- **Requires Accessibility** permission (System Settings → Privacy & Security → Accessibility); `gotoSpace` drives Mission Control through the Accessibility API. One-time manual grant, cannot be automated by chezmoi.
```

- [ ] **Step 2: Verify**

Run: `grep -c 'hs.eventtap' .agents/skills/hammerspoon/SKILL.md && grep -c 'see the .finicky. skill' .agents/skills/hammerspoon/SKILL.md`
Expected: `1` and `1` (the self-contained cross-reference is present).

- [ ] **Step 3: Commit**

```bash
git add .agents/skills/hammerspoon/SKILL.md
git commit -m "feat(skills): add hammerspoon skill (extracted from AGENTS.md)"
```

---

## Task 3: Create the `komorebi` skill

**Files:**
- Create: `.agents/skills/komorebi/SKILL.md`

Body is the `## Komorebi (Windows tiling)` section (235–247) verbatim.

- [ ] **Step 1: Write the frontmatter + scope header**

```markdown
---
name: komorebi
description: Komorebi Windows tiling-WM config for this chezmoi repo. Covers KOMOREBI_CONFIG_HOME, manage/layered/ignore rules, the never-Stop-Process-Force socket trap, whkd quirks, and reload. Triggers — Komorebi, Windows tiling WM, whkd, KOMOREBI_CONFIG_HOME, Stop-Process, sock file, AF_UNIX, layered_applications, FancyZones, reload-configuration. Load before changing home/dot_config/komorebi/* or home/dot_config/whkdrc.
---

# Komorebi (Windows tiling)

**Scope:** `home/dot_config/komorebi/*` (`komorebi.json`, `start.ps1`), `home/dot_config/whkdrc`.
```

- [ ] **Step 2: Append the verbatim gotchas**

Append the Komorebi section body (AGENTS.md lines 235–247, starting at "Komorebi is the Windows tiling WM…" through the `reload-configuration` bullet) verbatim after the scope header. Deterministic extraction:

```bash
sed -n '235,247p' AGENTS.md >> .agents/skills/komorebi/SKILL.md
```

- [ ] **Step 3: Verify no bullet lost**

Run: `grep -c 'KOMOREBI_CONFIG_HOME\|Stop-Process -Force\|is_paused\|FancyZones\|reload-configuration' .agents/skills/komorebi/SKILL.md`
Expected: `5`.

- [ ] **Step 4: Commit**

```bash
git add .agents/skills/komorebi/SKILL.md
git commit -m "feat(skills): add komorebi skill (extracted from AGENTS.md)"
```

---

## Task 4: Create the `mise-on-windows` skill

**Files:**
- Create: `.agents/skills/mise-on-windows/SKILL.md`

Body is the `## mise on Windows` section (253–257) verbatim.

- [ ] **Step 1: Write the frontmatter + scope header**

```markdown
---
name: mise-on-windows
description: mise on Windows gotchas for this chezmoi repo — the Chocolatey mise package omits mise-shim.exe, breaking binary-path resolution for MCP servers/IDEs. Covers shim placement, the always-run recovery guard, PS 5.1 stderr promotion, and the claude-code-win32 optional-dep trap. Triggers — mise Windows, mise-shim.exe, binary path, file shim mode, MCP servers, cannot find binary path, Chocolatey mise, reshim, PS 5.1 stderr, claude-code-win32. Load before changing home/.chezmoitemplates/windows-mise-shim-placement.ps1.tmpl, home/.chezmoiscripts/run_after_97_mise_shim_windows.ps1.tmpl, or the mise parts of run_onchange_after_bootstrap_windows.ps1.tmpl.
---

# mise on Windows

**Scope:** `home/.chezmoitemplates/windows-mise-shim-placement.ps1.tmpl`, `home/.chezmoiscripts/run_after_97_mise_shim_windows.ps1.tmpl`, and the mise-shim portion of `home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl` (shared with the `windows-internals` skill).
```

- [ ] **Step 2: Append the verbatim gotchas**

```bash
sed -n '253,257p' AGENTS.md >> .agents/skills/mise-on-windows/SKILL.md
```

- [ ] **Step 3: Verify**

Run: `grep -c 'mise-shim.exe\|run_after_97_mise_shim_windows\|ProcessStartInfo\|claude-code-win32' .agents/skills/mise-on-windows/SKILL.md`
Expected: `4`.

- [ ] **Step 4: Commit**

```bash
git add .agents/skills/mise-on-windows/SKILL.md
git commit -m "feat(skills): add mise-on-windows skill (extracted from AGENTS.md)"
```

---

## Task 5: Create the `windows-internals` skill

**Files:**
- Create: `.agents/skills/windows-internals/SKILL.md`

This skill is an assembly: the Windows-operational bullets carved out of `## Windows support` (the bootstrap/elevation mechanics from line 162, plus 164 WezTerm, 165 ssh-tpm-agent, 168 dual-gpg, 171 WSL) PLUS the whole `## Rancher Desktop / Docker (Windows)` section (222–229). The Rancher-after-WSL ordering note is preserved in prose.

- [ ] **Step 1: Write the frontmatter + authored sections**

```markdown
---
name: windows-internals
description: Windows-operational internals for this chezmoi repo — WSL cloud-init provisioning, Rancher Desktop/Docker, ssh-tpm-agent commit signing, the dual gpg.exe split, WezTerm, and the Windows bootstrap/elevation block. Triggers — Windows internals, WSL, cloud-init, rsync --delete, Rancher Desktop, moby, rdctl, Docker daemon pipe, ssh-tpm-agent, TPM, two gpg.exe, WezTerm, Windows bootstrap, elevation, YASB. Load before changing Windows-operational scripts/data.
---

# Windows internals

**Scope:** `home/.chezmoiscripts/*windows*.ps1.tmpl` (except the mise-shim scripts — see the `mise-on-windows` skill), `home/.chezmoiscripts/run_after_96_rancher_desktop_windows.ps1.tmpl`, `home/.chezmoidata/wsl/`, `home/.chezmoidata/ssh-tpm-agent.yaml`, `home/.chezmoidata/ssh-signing.yaml`, `home/private_dot_ssh/allowed_signers.tmpl`, `home/.chezmoitemplates/wsl-*.tmpl`, `home/dot_config/wezterm/`.

## Windows bootstrap / elevation

- **Windows bootstrap** — `home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl` installs packages via Chocolatey (`choco install -y`) and Winget, runs `mise install`, syncs Neovim plugins, and configures/starts YASB autostart via `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. `home/.chezmoiscripts/run_onchange_after_choco_review_windows.ps1.tmpl` runs interactive Chocolatey drift review after overlay changes when `bash` is available. Runs only on Windows. The elevated block does **not** skip Chocolatey/WSL when `CI` is set (same code path as interactive runs; `windows-elevation.ps1.tmpl` still avoids UAC in CI by running the block in-process). The same bootstrap script also places `mise-shim.exe` — that part is owned by the `mise-on-windows` skill.
```

- [ ] **Step 2: Append the verbatim Windows-support deep bullets**

Append lines 164, 165, 168, 171 verbatim (WezTerm, ssh-tpm-agent, two gpg.exe, WSL). These are non-contiguous, so extract them individually:

```bash
{
  echo
  echo "## WezTerm, ssh-tpm-agent, gpg, WSL"
  echo
  sed -n '164p;165p;168p;171p' AGENTS.md
} >> .agents/skills/windows-internals/SKILL.md
```

- [ ] **Step 3: Append the Rancher Desktop section verbatim**

```bash
{
  echo
  echo "## Rancher Desktop / Docker (Windows)"
  echo
  sed -n '222,229p' AGENTS.md
} >> .agents/skills/windows-internals/SKILL.md
```

The Rancher ordering note ("The script runs after WSL ensure (95)…", line 228) is included in that range — confirm it survived in Step 4.

- [ ] **Step 4: Verify the assembly**

Run: `grep -c 'WezTerm\|ssh-tpm-agent\|Two .gpg.exe.\|WSL\|moby\|after WSL ensure' .agents/skills/windows-internals/SKILL.md`
Expected: at least `6` (each topic present, plus the ordering note).

- [ ] **Step 5: Commit**

```bash
git add .agents/skills/windows-internals/SKILL.md
git commit -m "feat(skills): add windows-internals skill (WSL/Rancher/ssh-tpm/gpg/WezTerm)"
```

---

## Task 6: Rewrite AGENTS.md — pointers, Windows split, deletions, cleanups

**Files:**
- Modify: `AGENTS.md`

Do the inserts BEFORE the deletions so the survivor content is relocated before its source section is removed. All deletions remove content that now lives in the skills (Tasks 1–5) or is redundant.

- [ ] **Step 1: Add the two macOS skill pointers after the "Other config" bullet, and drop "finicky" from it**

Edit the "Other config" bullet (line 145):

Old:
```
- **Other config** – `home/dot_config/` includes tmux, mise, finicky; `home/private_dot_gnupg/` for GnuPG (private permissions).
```
New:
```
- **Other config** – `home/dot_config/` includes tmux, mise; `home/private_dot_gnupg/` for GnuPG (private permissions).
- **Finicky** – Load `.agents/skills/finicky/SKILL.md` before changing the Finicky config (`home/dot_config/finicky.js.tmpl`).
- **Hammerspoon (macOS Spaces)** – Load `.agents/skills/hammerspoon/SKILL.md` before changing `home/dot_hammerspoon/*`.
```

- [ ] **Step 2: Add the Windows conventions cluster (relocated cross-platform survivors + Windows skill pointers) at the end of the Repo-specific conventions block**

Insert AFTER the "Cursor, Codex, and Claude-related tools…" bullet (line 153, the last bullet before the `---` at 154):

New text to insert:
```
- **OS-conditional deploys** – `home/.chezmoiignore` uses `{{ if eq .chezmoi.os "windows" }}` / `{{ if ne .chezmoi.os "windows" }}` blocks to control which targets deploy per platform. Native Windows deploys cross-platform configs (git, nvim, mise, opencode) plus WezTerm and skips Unix-only targets (zsh, brew, tmux, ghostty, kitty, finicky, gnupg, scripts). When adding a new config, decide cross-platform / Unix-only / Windows-only and update `.chezmoiignore` accordingly.
- **OS-guarding chezmoiscripts** – bash scripts (`.sh.tmpl`) must be wrapped in `{{ if ne .chezmoi.os "windows" }}` and PowerShell scripts (`.ps1.tmpl`) in `{{ if eq .chezmoi.os "windows" }}` so they render to empty (and chezmoi skips them) on the wrong OS.
- **Windows packages** – Windows uses Chocolatey (`choco`), not winget/scoop. Chocolatey/Winget package lists live in `home/.chezmoidata/chocolatey/*.yaml` and `home/.chezmoidata/winget/*.yaml` as `overlays.<name>.packages` (brew-style overlay merge; lists concatenated in lexical overlay order).
- **Komorebi (Windows tiling)** – Load `.agents/skills/komorebi/SKILL.md` before changing `home/dot_config/komorebi/*` or `home/dot_config/whkdrc`.
- **mise on Windows** – Load `.agents/skills/mise-on-windows/SKILL.md` before changing `home/.chezmoitemplates/windows-mise-shim-placement.ps1.tmpl`, `home/.chezmoiscripts/run_after_97_mise_shim_windows.ps1.tmpl`, or the mise parts of `home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl`.
- **Windows internals** – Load `.agents/skills/windows-internals/SKILL.md` before changing Windows-operational scripts/data: `home/.chezmoiscripts/*windows*.ps1.tmpl`, `home/.chezmoiscripts/run_after_96_rancher_desktop_windows.ps1.tmpl`, `home/.chezmoidata/wsl/`, `home/.chezmoidata/ssh-tpm-agent.yaml`, `home/.chezmoidata/ssh-signing.yaml`, `home/private_dot_ssh/allowed_signers.tmpl`, `home/.chezmoitemplates/wsl-*.tmpl`, `home/dot_config/wezterm/`.
```

- [ ] **Step 3: Delete the entire `## Windows support` section**

It has been split: cross-platform survivors moved to conventions (Step 2), deep internals moved to the `windows-internals` skill (Task 5), `install.ps1.tmpl` (163) is already covered by the "Install script templates" / "Root-level" bullets, and the OpenCode/Atlassian bullet (166) is deleted as mislabeled cross-platform MCP gating.

```bash
# deletes from the "## Windows support" heading through the "---" that closes it
perl -0pi -e 's/## Windows support\n.*?\n---\n\n//s' AGENTS.md
```

Verify: `grep -c '^## Windows support' AGENTS.md` → `0`; `grep -c '^## Homebrew management' AGENTS.md` → `1` (the section after it survived).

- [ ] **Step 4: Delete the five tail sections (Finicky, Hammerspoon, Rancher, Komorebi, mise on Windows)**

They now live in skills. This removes everything from the `## Finicky config changes` heading up to (not including) `## Continuous maintenance (meta-rule)`, leaving the preceding `---` separator intact.

```bash
perl -0pi -e 's/## Finicky config changes\n.*?(?=## Continuous maintenance)//s' AGENTS.md
```

Verify: `grep -nE '^## (Finicky|Hammerspoon|Rancher|Komorebi|mise on Windows)' AGENTS.md` → no output.

- [ ] **Step 5: Update the Continuous-maintenance meta-rule**

Add a line so future subsystem gotchas go to skills, not inline. Edit the meta-rule list:

Old:
```
- Keep this file concise — if it grows beyond ~200 lines of rules (excluding vault context), propose splitting into topic-specific files.
```
New:
```
- Keep this file concise — if it grows beyond ~200 lines of rules (excluding vault context), propose splitting into topic-specific files.
- New platform/app-specific subsystem gotchas go in a `.agents/skills/<name>/` skill with a one-line `Load …/SKILL.md before changing <globs>` pointer in Repo-specific conventions — not as a new inline `##` section. See [ADR-0003](docs/adr/0003-extract-subsystem-gotchas-to-repo-local-skills.md).
```

- [ ] **Step 6: Verify and commit**

```bash
wc -l AGENTS.md                                   # expect ~195-210
grep -n '^## ' AGENTS.md                          # no Finicky/Hammerspoon/Rancher/Komorebi/mise/Windows-support headers
grep -q 'if ne .chezmoi.os' AGENTS.md && echo "cross-platform guard rule still inline OK"
grep -q 'Load `.agents/skills/komorebi' AGENTS.md && echo "komorebi pointer OK"
git add AGENTS.md
git commit -m "refactor(agents): extract subsystem gotchas to skills, split Windows section"
```

---

## Task 7: Final verification (content-loss + trigger sanity)

**Files:** none (read-only checks). Fix any failure in the relevant earlier task, then re-commit.

- [ ] **Step 1: No gotcha lost — each subsystem's signature string left AGENTS.md and landed in exactly one skill**

```bash
for pat in "killall Finicky" "hs.eventtap" "KOMOREBI_CONFIG_HOME" "mise-shim.exe" "rancher-desktop"; do
  inmd=$(grep -rl "$pat" .agents/skills/ | wc -l | tr -d ' ')
  inagents=$(grep -c "$pat" AGENTS.md)
  echo "$pat: skills=$inmd agents=$inagents (want skills>=1, agents=0)"
done
```
Expected: every line `skills>=1` and `agents=0`. (Note: "rancher-desktop" the literal string only needs to be absent from AGENTS.md; the Rancher content lives in `windows-internals`.)

- [ ] **Step 2: Cross-platform mechanics stayed inline**

```bash
grep -q 'if eq .chezmoi.os "windows"' AGENTS.md && grep -q 'if ne .chezmoi.os "windows"' AGENTS.md && echo "OS-guard syntax inline OK"
grep -q 'Chocolatey' AGENTS.md && echo "Windows package convention inline OK"
```
Expected: both OK lines print.

- [ ] **Step 3: Glob coverage — every moved subsystem's real files match a pointer glob**

```bash
ls home/dot_config/finicky.js.tmpl home/dot_hammerspoon/* home/dot_config/komorebi/* home/dot_config/whkdrc \
   home/.chezmoitemplates/wsl-*.tmpl home/.chezmoidata/ssh-signing.yaml home/.chezmoidata/ssh-tpm-agent.yaml \
   home/.chezmoiscripts/run_after_96_rancher_desktop_windows.ps1.tmpl \
   home/.chezmoitemplates/windows-mise-shim-placement.ps1.tmpl
```
Expected: all listed (no "No such file"). Cross-check each against a pointer glob in `AGENTS.md` Step 2.

- [ ] **Step 4: Skill discovery**

The five new skills should appear in the agent's available-skills list (same mechanism as `homebrew-management`). If the harness caches the skill list, reload the session. Confirm: `ls .agents/skills/` shows all nine skill dirs (4 existing + 5 new).

- [ ] **Step 5: No chezmoi impact**

```bash
DOTFILES_SKIP_BITWARDEN=1 chezmoi diff | head -5   # must not reference .agents/ ; AGENTS.md is not a managed target
```
Expected: no diff lines mentioning `.agents/` or `AGENTS.md` (both are outside the source state).

- [ ] **Step 6: Final commit if any fixups were made**

```bash
git status
git log --oneline -8
```

---

## Self-review notes (for the executor)

- **Verbatim integrity:** Tasks 3, 4, 5 extract by line range from `AGENTS.md` at commit `7c07b03`. If `grep -n '^## '` shows different line numbers, the file drifted — re-derive ranges from the section headers before running the `sed` extracts.
- **Order matters in Task 6:** inserts (Steps 1–2) before deletions (Steps 3–4), so the relocated survivors are in place before their source sections are cut.
- **The two `perl -0pi` deletions are the riskiest steps.** After each, immediately run its verify command; if a heading you meant to keep vanished, `git checkout AGENTS.md` and redo with a tighter pattern.
- **Rollback (per ADR-0003):** if a subsystem edit later regresses because an agent missed the skill, move that subsystem's content back inline above its pointer in one commit.
