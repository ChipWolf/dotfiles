# Agent guide: chezmoi dotfiles repo

This repo is a **chezmoi** dotfiles repository. It defines config files and scripts that are applied to the user’s home directory via `chezmoi apply`.

---

## Important: use the official docs

**Do not guess** about chezmoi behavior, naming, or structure. When in doubt:

- **Consult the official docs:** [https://www.chezmoi.io/](https://www.chezmoi.io/)
- Use the site search and reference sections for: source state attributes, special files/directories, scripts, templating, target types, and application order.
- Prefer [chezmoi user guide](https://www.chezmoi.io/user-guide/setup/) and [reference](https://www.chezmoi.io/reference/concepts/) over inferring from this file alone.

This document summarizes how _this_ repo is laid out and points to official concepts; it is not a substitute for the chezmoi docs.

---

## Concepts (from chezmoi)

- **Source directory** – Where the source state lives. Default `~/.local/share/chezmoi`; this repo is that (or a clone of it).
- **Source state** – Desired state of the home directory (files, dirs, scripts, etc.). In this repo the source state root is set by `.chezmoiroot` (see below).
- **Target / destination** – Usually `~`. Each target is a file, directory, or symlink in the destination.
- **Config file** – Machine-specific data, usually `~/.config/chezmoi/chezmoi.toml`. Can be generated from a template at init.

See [Concepts](https://www.chezmoi.io/reference/concepts/).

---

## This repo’s layout

### Source state root: `.chezmoiroot`

The file [.chezmoiroot](.chezmoiroot) at the repo root contains `home`. So the **source state** is read from the `home/` directory. All managed targets and special files (e.g. config template, scripts) are under `home/`.

- [.chezmoiroot](https://www.chezmoi.io/reference/special-files/chezmoiroot/) is read first; it sets the path used for the rest of the source state.
- The working tree (git repo) is the parent of that path; `install.sh.tmpl`, `install.ps1.tmpl`, `.macos`, `.gitignore`, and `README.md` live at repo root and are **not** part of the source state.

### Naming: source state attributes

Paths under `home/` use chezmoi’s **source state attributes** (prefixes/suffixes). Only the main ones used in this repo are listed here; the full table and order rules are in the reference.

| Prefix               | Effect                                                                  |
|----------------------|-------------------------------------------------------------------------|
| `dot_`               | Target name gets a leading dot (e.g. `dot_gitconfig` → `~/.gitconfig`). |
| `private_`           | Target has no group/world permissions (e.g. `private_dot_gnupg`).       |
| `executable_`        | Target is executable (e.g. `executable_7zw` → `~/.7zw`).                |
| `run_`               | Content is a script run on apply.                                       |
| `run_once_`          | Script run once per content (by hash).                                  |
| `before_` / `after_` | With `run_*`: run before or after updating files.                       |

| Suffix  | Effect                                                                                                                            |
|---------|-----------------------------------------------------------------------------------------------------------------------------------|
| `.tmpl` | Content is a [text/template](https://pkg.go.dev/text/template) (see [Templating](https://www.chezmoi.io/user-guide/templating/)). |

Other attributes (e.g. `create_`, `modify_`, `remove_`, `encrypted_`, `symlink_`, etc.) exist; see [Source state attributes](https://www.chezmoi.io/reference/source-state-attributes/) and [Target types](https://www.chezmoi.io/reference/target-types/) — **do not guess** prefix/suffix behavior.

- **Directories:** e.g. `dot_config/` under `home/` → `~/.config/`. No leading dot in the directory name; the `dot_` convention applies to the path (e.g. `home/dot_config/nvim/` → `~/.config/nvim/`).
- **Files:** `home/dot_zshenv` → `~/.zshenv`, `home/dot_config/zsh/dot_zshrc` → `~/.config/zsh/.zshrc`.

### Special files and directories (under source state root)

- **`home/.chezmoi.toml.tmpl`** – Template for the chezmoi config file. Used by `chezmoi init` (and `apply --init`) to generate `~/.config/chezmoi/chezmoi.toml`. Sets `sourceDir` and custom data (e.g. `codespaces`).
- **`home/.chezmoiscripts/`** – Scripts here are run as normal run scripts but **do not** create a directory in the target state. They still need the `run_` (and optionally `once_`/`onchange_`, `before_`/`after_`) prefix. See [.chezmoiscripts/](https://www.chezmoi.io/reference/special-directories/chezmoiscripts/).

Other special files/dirs (e.g. `.chezmoiignore`, `.chezmoiremove`, `.chezmoidata/`, `.chezmoitemplates/`, `.chezmoiexternals/`) are documented in [Special files](https://www.chezmoi.io/reference/special-files/) and [Special directories](https://www.chezmoi.io/reference/special-directories/). Use the docs to add or change behavior.

---

## Scripts

- **`run_`** – Run every `chezmoi apply`.
- **`run_once_`** – Run once per content hash (tracked in chezmoi state).
- **`run_onchange_`** – Run when script content has changed.
- **`before_`** – Run before updating files; **`after_`** – run after updating files.

Scripts should be **idempotent**. Scripts in `home/.chezmoiscripts/` do not create a target directory. Scripts with `.tmpl` are templated first; if the result is empty/whitespace, the script is not run.
Scripts should be **fail-fast**. Do not swallow errors in chezmoiscripts (`-IgnoreExitCode`, warning-and-continue returns, or `|| true`) for core bootstrap/provisioning/package steps; propagate non-zero exits so `chezmoi apply` stops immediately.
For scripts that should run only when managed inputs change, prefer `run_onchange_*` plus a hash comment near the top (for example `# {{ include "path/to/input" | sha256sum }}` or a hash of templated/serialized data), following the existing repo pattern.

See [Use scripts to perform actions](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/) and [Target types – Scripts](https://www.chezmoi.io/reference/target-types/#scripts).

---

## Templating and data

- Templates use Go’s [text/template](https://pkg.go.dev/text/template) plus [sprig](http://masterminds.github.io/sprig/) and [chezmoi-specific functions](https://www.chezmoi.io/reference/templates/functions/).
- Data: `.chezmoi.*` (e.g. `.chezmoi.os`, `.chezmoi.hostname`), config `[data]`, `.chezmoidata.*` / `.chezmoidata/`, etc. Run `chezmoi data` on a machine to inspect.
- In this repo, `home/.chezmoi.toml.tmpl` sets `data.codespaces` from env; use `{{ .codespaces }}` in templates for Codespaces-specific logic.

See [Templating](https://www.chezmoi.io/user-guide/templating/) and [Templates](https://www.chezmoi.io/reference/templates/).

---

## Editing and adding files

1. **Edit in the repo** under `home/` (the source state root). Do not rely on editing only in `~`; apply from the repo with `chezmoi apply`.
2. **Add a new target:** Create the file under `home/` with the correct attributes (e.g. `dot_*`, `dot_config/...`). Optionally import from the machine: `chezmoi add ~/path/to/target` (and `--template` if it should be a template).
3. **After editing:** `chezmoi diff` then `chezmoi apply`. To re-import from the machine: `chezmoi re-add ~/path`.
4. **Making a file a template:** `chezmoi chattr +template ~/.somefile` or add the `.tmpl` suffix in the source.

### Removing a managed file

Deleting a file from the chezmoi source does **not** remove it from the target (`~/`). Chezmoi only removes targets when explicitly told to via documented removal mechanisms, for example `.chezmoiremove`. If you delete a source file and run `chezmoi apply`, the deployed target is left behind as an unmanaged file.

- Verify the removal mechanism against the official chezmoi docs before changing the source state.
- Prefer declaring removals in `.chezmoiremove` when retiring a previously managed target.
- When a deployed file is stale because its source entry was removed or renamed, default to `.chezmoiremove` or another documented chezmoi removal mechanism before touching the target path directly.
- Use other documented chezmoi removal semantics only when they are a better fit for the target type.
- Delete the source file from `home/` only after the removal is represented in chezmoi.
- Run `chezmoi apply` so chezmoi removes the deployed target.
- Do not delete the deployed file directly from `~/`, `~/.config`, or similar target paths unless the documented chezmoi removal has already been recorded and applied.

---

## Running `chezmoi apply`

- Keep source edits, `chezmoi apply`, and git operations as separate commands unless a later step strictly depends on the previous one within the same concern.
- When `chezmoi apply` triggers a brew bundle run (via an onchange script), treat it as fire-and-forget once the apply succeeds.
- If `chezmoi apply` fails because an unrelated template needs a secret (e.g. Bitwarden locked), apply only the file you need with `chezmoi apply <target-path>` to bypass the failing template.
- Commit chezmoi source changes to the relevant branch before testing with `chezmoi apply`. Deploying from an uncommitted `--source <worktree-path>` is fragile: any subsequent `chezmoi apply` from a different source silently reverts the deploy, and chezmoi records the reverted content as its last-written state so nothing looks wrong on inspection. Diagnose suspected reverts by comparing `Get-FileHash` of the deployed file against the source and against chezmoi's tracked `contentsSHA256` (visible via `chezmoi state get-bucket --bucket=entryState`).
- **`modify_` JSON templates re-sort keys, so `chezmoi diff` looks destructive when it isn't.** The `modify_*.json` templates (e.g. `home/modify_dot_claude.json`) end in `toPrettyJson`, which emits keys alphabetically while the live file is in insertion order. `chezmoi diff` of such a target therefore shows large blocks of "removed" keys (`numStartups`, `tipsHistory`, etc.) that are merely reordered, not lost, and a truncated `head` of that diff is especially misleading. Before trusting the diff, render the full target with `chezmoi cat <target>` and compare the *set* of top-level keys plus the specific managed block (e.g. `mcpServers`); confirm intent there, not by eyeballing the diff.

---

## Repo-specific conventions

- **Project glossary & ADRs** – `CONTEXT.md` (repo root) defines the domain language for the config fan-out (source of truth, overlay, render target, target enablement, condition gate, prep partial, eligible set). `docs/adr/` records architecture decisions; `0001` documents the source-of-truth → many-opt-in-targets pattern and `0002` records folding the strict/loose per-rule permission gate into the shared partial as a `gate` parameter. When a concept renders to multiple tools, prefer a shared **prep partial** under `home/.chezmoitemplates/` that does the target-independent filtering/resolution and emits JSON (consumed via `includeTemplate ... | fromJson`); keep only per-target schema shaping in each render template. Existing prep partials: `mcp-eligible-servers.tmpl`, `agent-permission-rules.tmpl` (collection + optional `gate` strict/loose), `overlay-flatten.tmpl` (sortAlpha overlay walk + list concat for chocolatey/winget/registry; brew keeps its own walk because it gates overlays by env condition), and `modify-stdin.tmpl` (the stdin→merged-dict preamble every `modify_` template shares).

- **Universal agent definitions** – `home/dot_agents/AGENTS.md` (→ `~/.agents/AGENTS.md`). Cross-tool agent rules shared by OpenCode, Claude Code, Cursor, and pi. Edit the chezmoi source, not the deployed files. (Universal *skills* are no longer at `~/.agents/skills/`; they're distributed per-agent via the `vercel-labs/skills` CLI from the local `skills/` source at the repo root — see "Skill distribution updates" below.)
- **Repo-local skills** – Shared project skills live under `.agents/skills/`.
- **MCP server updates** – Load `.agents/skills/update-mcp-servers/SKILL.md` before changing `home/.chezmoidata/mcps/*.yaml`, `home/dot_cursor/mcp.json.tmpl`, `home/dot_config/opencode/modify_opencode.json`, or `home/modify_dot_claude.json` (Claude Code `~/.claude.json` merge).
- **Agent permission updates** – Load `.agents/skills/update-agent-permissions/SKILL.md` before changing `home/.chezmoidata/agent-permissions/*.yaml`, `schemas/agent-permissions.schema.json`, or OpenCode permission template rendering.
- **Homebrew updates** – Load `.agents/skills/homebrew-management/SKILL.md` before changing `home/Brewfile.tmpl`, `home/Brewfile.ignore`, brew overlay data, brew-related chezmoiscripts, or `home/dot_scripts/executable_brew-review`.
- **Skill distribution updates** – Load `.agents/skills/update-skills/SKILL.md` before changing `home/.chezmoidata/skills/*.yaml`, `schemas/skills.schema.json`, the `skills/` directory at the repo root, or the skills install / review scripts (`home/.chezmoiscripts/run_onchange_after_skills*.tmpl`, `home/dot_scripts/executable_skills-review`). When fixing an installed skill under `~/.agents/skills`, make the durable change in the repo source `skills/<skill-name>/` first, then sync/apply it to deployed copies; never leave the deployed copy as the only edited version.
- **Zsh** – Primary config under `home/dot_config/zsh/`: `dot_zshrc`, `dot_zshenv`, `dot_zprofile`, `dot_zplugins`, `dot_zshrc.d/`, `dot_zfunctions/`, `dot_p10k.zsh`. Top-level `home/dot_zshenv` and `home/dot_profile` set `ZDOTDIR` / `XDG_CONFIG_HOME` and are sourced by the shell.
- **Neovim** – `home/dot_config/nvim/` (LazyVim-style: `init.lua`, `lua/config/`, `lua/plugins/`).
- **OpenCode** – `home/dot_config/opencode/modify_opencode.json` (merges into `~/.config/opencode/opencode.json`). This is the global OpenCode config: model, MCP servers, permissions, etc. It is a chezmoi `modify_` template so OpenCode's own writes to the file are preserved on apply (only the keys we explicitly manage are overwritten: `$schema`, `autoupdate`, `model`, `plugin`, `permission`, `mcp`). Edit the source here when updating OpenCode settings.
- **OpenCode-specific agent rules** – `home/dot_config/opencode/AGENTS.md` (→ `~/.config/opencode/AGENTS.md`). OpenCode-specific rules (context-mode routing, subagents, custom commands) that extend the universal rules in `~/.agents/AGENTS.md`. Edit the source here and run `chezmoi apply`. Never edit `~/.config/opencode/AGENTS.md` directly.
- **mcpproxy** – `home/private_dot_mcpproxy/modify_mcp_config.json` (→ `~/.mcpproxy/mcp_config.json`). Renders the [smart-mcp-proxy/mcpproxy-go](https://github.com/smart-mcp-proxy/mcpproxy-go) config from `home/.chezmoidata/mcps/*.yaml` (same source of truth as Cursor, OpenCode, and Claude Code). Installed via Homebrew tap `smart-mcp-proxy/mcpproxy` on macOS/Linux and via pinned GitHub release installer on private Windows systems. Use the `update-mcp-servers` skill when changing servers.
- **Claude Code MCP** – `home/modify_dot_claude.json` merges `mcpServers` into `~/.claude.json` from the same YAML; opt in per server with `targets.claudeCode.enabled: true`. Entries use Claude Code’s schema (`type: "stdio"` or `type: "http"` / `sse`, not Cursor’s `transport` field).
- **pi MCP servers** – `home/dot_pi/agent/mcp.json.tmpl` (→ `~/.pi/agent/mcp.json`). Renders pi-facing MCP servers from the same `home/.chezmoidata/mcps/*.yaml` source of truth. Pi has no built-in MCP support, so the `pi` target is opt-in: only servers with `targets.pi.enabled: true` are emitted. Use the `update-mcp-servers` skill when changing servers.
- **mise tools** – Declared in `home/dot_config/mise/config.toml.tmpl`. `home/.chezmoiscripts/run_onchange_after_mise_install.sh.tmpl` runs `mise install` whenever that config changes (hash-pinned via `include`/`sha256sum`), so adding/removing/repinning mise tools reconciles on `chezmoi apply` without re-running the full bootstrap. The bootstrap script still runs `mise install` on first provisioning; this onchange handles ongoing changes.
- **pi (`@earendil-works/pi-coding-agent`)** – Installed declaratively as a **mise** tool via the `npm:` backend, **not** via `npm install -g`. Declared in `home/dot_config/mise/config.toml.tmpl` as `"npm:@earendil-works/pi-coding-agent" = "latest"`. The `pi` binary is exposed through `~/.local/share/mise/shims/pi`. Do not reintroduce `npm install -g @earendil-works/pi-coding-agent`. Pi packages (extensions/skills/prompts/themes) are declared in `home/dot_pi/agent/modify_settings.json`, a chezmoi `modify_` template that merges the `packages` array into `~/.pi/agent/settings.json` while preserving runtime fields (`lastChangelogVersion`, `defaultProvider`, etc.). `home/.chezmoiscripts/run_onchange_after_pi_packages.sh.tmpl` runs `pi update --extensions` whenever the declared package list changes (hash-pinned via `include`/`sha256sum`); it runs after `mise_install` alphabetically so newly-declared pi versions are present before package reconcile.
- **Other config** – `home/dot_config/` includes tmux, mise; `home/private_dot_gnupg/` for GnuPG (private permissions).
- **Finicky** – Load `.agents/skills/finicky/SKILL.md` before changing the Finicky config (`home/dot_config/finicky.js.tmpl`).
- **Hammerspoon (macOS Spaces)** – Load `.agents/skills/hammerspoon/SKILL.md` before changing `home/dot_hammerspoon/*`.
- **Executable** – `home/dot_scripts/executable_brew-review` (→ `~/.scripts/brew-review`) is the Homebrew drift review script, and `home/dot_scripts/executable_choco-review` is the Chocolatey drift review script (Windows source-side usage from Git Bash/WSL). `home/dot_scripts/executable_7zw` (→ `~/.scripts/7zw`) is a 7-zip wrapper. All script helpers live in `dot_scripts/` — not `dot_zfunctions/` (see Brew section below).
- **Bootstrap** – `home/.chezmoiscripts/run_once_before_bootstrap.sh.tmpl` runs once before other updates (install deps, brew bundle, oh-my-zsh, mise, etc.). It is OS-aware (darwin/linux) and sets Codespaces overrides when `codespaces` is true.
- **Root-level (not in source state)** – `install.sh.tmpl` and `install.ps1.tmpl` are installer templates for release assets; `.macos` holds macOS defaults; `.gitignore` excludes local/private artifacts (e.g. `*.local.*`, vim swap/undo). Do not add ignored patterns to the source state.
- **README "What you get" table** – The tool table in `README.md` is sorted by category: shell/prompt, terminal emulators, multiplexer, editor, dev tools, version control, security, package/runtime management, then platform-specific utilities. When adding or removing a managed tool, update this table and preserve the sort order. Platform columns (macOS, Linux, Windows, Codespaces) must reflect what `.chezmoiignore` actually deploys.
- **Install script templates** – `install.sh.tmpl` and `install.ps1.tmpl` are the source of truth for release installers. The release workflow renders `install.sh` and `install.ps1` from templates with repository/image/tag values before uploading release assets.
- **Template readability** – Keep chezmoi template source files readable: use clear indentation, split complex logic into understandable blocks, and avoid flattening everything to the left margin with aggressive whitespace trimming unless required for output correctness.
- **Bitwarden in automation** – Set `DOTFILES_SKIP_BITWARDEN=1` when running `chezmoi apply` in non-interactive/agent contexts. Templates that use the `bitwarden` function must honor this variable to avoid `bw` prompts/failures during automated runs.
- **Cursor, Codex, and Claude-related tools deploy only on private machines** – Never add Cursor, Codex (`npm:@openai/codex`), Claude Code, Claude Desktop, or any other Claude/Anthropic tooling to a base/unconditional overlay. Gate them per subsystem: `{{ if .private }}` in chezmoi templates (e.g. `home/dot_config/mise/config.toml.tmpl`), `{ kind: env, name: PRIVATE, op: set }` in Brewfile overlay conditions, and `conditions: { private: true }` in `home/.chezmoidata/mcps/*.yaml` and `home/.chezmoidata/agent-permissions/*.yaml`. The `private` chezmoi data value is `true` on Windows or when `~/.private` exists (see `home/.chezmoi.toml.tmpl`).
- **OS-conditional deploys** – `home/.chezmoiignore` uses `{{ if eq .chezmoi.os "windows" }}` / `{{ if ne .chezmoi.os "windows" }}` blocks to control which targets deploy per platform. Native Windows deploys cross-platform configs (git, nvim, mise, opencode) plus WezTerm and skips Unix-only targets (zsh, brew, tmux, ghostty, kitty, finicky, gnupg, scripts). When adding a new config, decide cross-platform / Unix-only / Windows-only and update `.chezmoiignore` accordingly.
- **OS-guarding chezmoiscripts** – bash scripts (`.sh.tmpl`) must be wrapped in `{{ if ne .chezmoi.os "windows" }}` and PowerShell scripts (`.ps1.tmpl`) in `{{ if eq .chezmoi.os "windows" }}` so they render to empty (and chezmoi skips them) on the wrong OS.
- **Windows packages** – Windows uses Chocolatey (`choco`), not winget/scoop. Chocolatey/Winget package lists live in `home/.chezmoidata/chocolatey/*.yaml` and `home/.chezmoidata/winget/*.yaml` as `overlays.<name>.packages` (brew-style overlay merge; lists concatenated in lexical overlay order).
- **Komorebi (Windows tiling)** – Load `.agents/skills/komorebi/SKILL.md` before changing `home/dot_config/komorebi/*` or `home/dot_config/whkdrc`.
- **mise on Windows** – Load `.agents/skills/mise-on-windows/SKILL.md` before changing `home/.chezmoitemplates/windows-mise-shim-placement.ps1.tmpl`, `home/.chezmoiscripts/run_after_97_mise_shim_windows.ps1.tmpl`, or the mise parts of `home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl`.
- **Windows internals** – Load `.agents/skills/windows-internals/SKILL.md` before changing Windows-operational scripts/data: `home/.chezmoiscripts/*windows*.ps1.tmpl`, `home/.chezmoiscripts/run_after_96_rancher_desktop_windows.ps1.tmpl`, `home/.chezmoidata/wsl/`, `home/.chezmoidata/ssh-tpm-agent.yaml`, `home/.chezmoidata/ssh-signing.yaml`, `home/private_dot_ssh/allowed_signers.tmpl`, `home/.chezmoitemplates/wsl-*.tmpl`, `home/dot_config/wezterm/`.

---

## Homebrew management

- Load `.agents/skills/homebrew-management/SKILL.md` before changing Brewfile entries, brew scripts, brew-review, tap logic, or Brewfile env var handling.

---

## Quick reference links

- [chezmoi home](https://www.chezmoi.io/)
- [Concepts](https://www.chezmoi.io/reference/concepts/)
- [Source state attributes](https://www.chezmoi.io/reference/source-state-attributes/)
- [Target types](https://www.chezmoi.io/reference/target-types/)
- [Special files](https://www.chezmoi.io/reference/special-files/) and [Special directories](https://www.chezmoi.io/reference/special-directories/)
- [Use scripts to perform actions](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/)
- [Templating](https://www.chezmoi.io/user-guide/templating/)
- [Setup](https://www.chezmoi.io/user-guide/setup/)

When adding or changing attributes, scripts, or templates, verify behavior against the docs above rather than guessing.

---

## Continuous maintenance (meta-rule)

- After every substantive conversation, review whether this file needs updating.
- Add convention rules when the user establishes a new pattern or corrects agent behaviour.
- If stderr shows `mise WARN missing: ...` during commands in this repo, run `mise install` before continuing.
- Before ending a session, check that the git working directory is clean. If it is not clean, either commit/apply/push when appropriate, or ask the user via the question tool when intent is unclear.
- Never remove rules without explicit user confirmation.
- Keep this file concise — if it grows beyond ~200 lines of rules (excluding vault context), propose splitting into topic-specific files.
- New platform/app-specific subsystem gotchas go in a `.agents/skills/<name>/` skill with a one-line `Load …/SKILL.md before changing <globs>` pointer in Repo-specific conventions, not as a new inline `##` section. See [ADR-0003](docs/adr/0003-extract-subsystem-gotchas-to-repo-local-skills.md).
- When in doubt, append a new rule rather than silently adopting a convention that isn't written down.
