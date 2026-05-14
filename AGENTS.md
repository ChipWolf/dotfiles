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

## Repo-specific conventions

- **Universal agent definitions** – `home/dot_agents/` (→ `~/.agents/`). Cross-tool agent rules and skills shared by OpenCode, Claude Code, Cursor, and pi. Universal rules live in `home/dot_agents/AGENTS.md`; universal skills in `home/dot_agents/skills/`. Edit the chezmoi source, not the deployed files.
- **Repo-local skills** – Shared project skills live under `.agents/skills/`.
- **MCP server updates** – Load `.agents/skills/update-mcp-servers/SKILL.md` before changing `home/.chezmoidata/mcps/*.yaml`, `home/dot_cursor/mcp.json.tmpl`, `home/dot_config/opencode/opencode.jsonc.tmpl`, or `home/modify_dot_claude.json` (Claude Code `~/.claude.json` merge).
- **Agent permission updates** – Load `.agents/skills/update-agent-permissions/SKILL.md` before changing `home/.chezmoidata/agent-permissions/*.yaml`, `schemas/agent-permissions.schema.json`, or OpenCode permission template rendering.
- **Homebrew updates** – Load `.agents/skills/homebrew-management/SKILL.md` before changing `home/Brewfile.tmpl`, `home/Brewfile.ignore`, brew overlay data, brew-related chezmoiscripts, or `home/dot_scripts/executable_brew-review`.
- **Zsh** – Primary config under `home/dot_config/zsh/`: `dot_zshrc`, `dot_zshenv`, `dot_zprofile`, `dot_zplugins`, `dot_zshrc.d/`, `dot_zfunctions/`, `dot_p10k.zsh`. Top-level `home/dot_zshenv` and `home/dot_profile` set `ZDOTDIR` / `XDG_CONFIG_HOME` and are sourced by the shell.
- **Neovim** – `home/dot_config/nvim/` (LazyVim-style: `init.lua`, `lua/config/`, `lua/plugins/`).
- **OpenCode** – `home/dot_config/opencode/opencode.jsonc.tmpl` (→ `~/.config/opencode/opencode.jsonc`). This is the global OpenCode config: model, MCP servers, permissions, etc. It is a chezmoi template (uses `.chezmoi.homeDir` for the Obsidian vault path). Edit the source here when updating OpenCode settings.
- **OpenCode-specific agent rules** – `home/dot_config/opencode/AGENTS.md` (→ `~/.config/opencode/AGENTS.md`). OpenCode-specific rules (context-mode routing, subagents, custom commands) that extend the universal rules in `~/.agents/AGENTS.md`. Edit the source here and run `chezmoi apply`. Never edit `~/.config/opencode/AGENTS.md` directly.
- **mcpproxy** – `home/private_dot_mcpproxy/modify_mcp_config.json` (→ `~/.mcpproxy/mcp_config.json`). Renders the [smart-mcp-proxy/mcpproxy-go](https://github.com/smart-mcp-proxy/mcpproxy-go) config from `home/.chezmoidata/mcps/*.yaml` (same source of truth as Cursor, OpenCode, and Claude Code). Installed via Homebrew tap `smart-mcp-proxy/mcpproxy` on macOS/Linux and via pinned GitHub release installer on private Windows systems. Use the `update-mcp-servers` skill when changing servers.
- **Claude Code MCP** – `home/modify_dot_claude.json` merges `mcpServers` into `~/.claude.json` from the same YAML; opt in per server with `targets.claudeCode.enabled: true`. Entries use Claude Code’s schema (`type: "stdio"` or `type: "http"` / `sse`, not Cursor’s `transport` field).
- **pi MCP servers** – `home/dot_pi/agent/mcp.json.tmpl` (→ `~/.pi/agent/mcp.json`). Renders pi-facing MCP servers from the same `home/.chezmoidata/mcps/*.yaml` source of truth. Pi has no built-in MCP support, so the `pi` target is opt-in: only servers with `targets.pi.enabled: true` are emitted. Use the `update-mcp-servers` skill when changing servers.
- **mise tools** – Declared in `home/dot_config/mise/config.toml.tmpl`. `home/.chezmoiscripts/run_onchange_after_mise_install.sh.tmpl` runs `mise install` whenever that config changes (hash-pinned via `include`/`sha256sum`), so adding/removing/repinning mise tools reconciles on `chezmoi apply` without re-running the full bootstrap. The bootstrap script still runs `mise install` on first provisioning; this onchange handles ongoing changes.
- **pi (`@mariozechner/pi-coding-agent`)** – Installed declaratively as a **mise** tool via the `npm:` backend, **not** via `npm install -g`. Declared in `home/dot_config/mise/config.toml.tmpl` as `"npm:@mariozechner/pi-coding-agent" = "latest"`. The `pi` binary is exposed through `~/.local/share/mise/shims/pi`. Do not reintroduce `npm install -g @mariozechner/pi-coding-agent`. Pi packages (extensions/skills/prompts/themes) are declared in `home/dot_pi/agent/modify_settings.json`, a chezmoi `modify_` template that merges the `packages` array into `~/.pi/agent/settings.json` while preserving runtime fields (`lastChangelogVersion`, `defaultProvider`, etc.). `home/.chezmoiscripts/run_onchange_after_pi_packages.sh.tmpl` runs `pi update --extensions` whenever the declared package list changes (hash-pinned via `include`/`sha256sum`); it runs after `mise_install` alphabetically so newly-declared pi versions are present before package reconcile.
- **Other config** – `home/dot_config/` includes tmux, mise, finicky; `home/private_dot_gnupg/` for GnuPG (private permissions).
- **Executable** – `home/dot_scripts/executable_brew-review` (→ `~/.scripts/brew-review`) is the Homebrew drift review script, and `home/dot_scripts/executable_choco-review` is the Chocolatey drift review script (Windows source-side usage from Git Bash/WSL). `home/dot_scripts/executable_7zw` (→ `~/.scripts/7zw`) is a 7-zip wrapper. All script helpers live in `dot_scripts/` — not `dot_zfunctions/` (see Brew section below).
- **Bootstrap** – `home/.chezmoiscripts/run_once_before_bootstrap.sh.tmpl` runs once before other updates (install deps, brew bundle, oh-my-zsh, mise, etc.). It is OS-aware (darwin/linux) and sets Codespaces overrides when `codespaces` is true.
- **Root-level (not in source state)** – `install.sh.tmpl` and `install.ps1.tmpl` are installer templates for release assets; `.macos` holds macOS defaults; `.gitignore` excludes local/private artifacts (e.g. `*.local.*`, vim swap/undo). Do not add ignored patterns to the source state.
- **README "What you get" table** – The tool table in `README.md` is sorted by category: shell/prompt, terminal emulators, multiplexer, editor, dev tools, version control, security, package/runtime management, then platform-specific utilities. When adding or removing a managed tool, update this table and preserve the sort order. Platform columns (macOS, Linux, Windows, Codespaces) must reflect what `.chezmoiignore` actually deploys.
- **Install script templates** – `install.sh.tmpl` and `install.ps1.tmpl` are the source of truth for release installers. The release workflow renders `install.sh` and `install.ps1` from templates with repository/image/tag values before uploading release assets.
- **Template readability** – Keep chezmoi template source files readable: use clear indentation, split complex logic into understandable blocks, and avoid flattening everything to the left margin with aggressive whitespace trimming unless required for output correctness.
- **Bitwarden in automation** – Set `DOTFILES_SKIP_BITWARDEN=1` when running `chezmoi apply` in non-interactive/agent contexts. Templates that use the `bitwarden` function must honor this variable to avoid `bw` prompts/failures during automated runs.

---

## Windows support

- **Native Windows** is supported — `chezmoi apply` deploys cross-platform configs (git, nvim, mise, opencode) and Windows-specific configs (WezTerm), while skipping Unix-only targets (zsh, brew, tmux, ghostty, kitty, finicky, gnupg, scripts, opencode-shims).
- **OS-conditional ignores** in `home/.chezmoiignore` use `{{ if eq .chezmoi.os "windows" }}` and `{{ if ne .chezmoi.os "windows" }}` blocks to control which targets are deployed per platform.
- **Bash chezmoiscripts** (`run_onchange_after_bootstrap.sh.tmpl`, `run_onchange_after_brew_review.sh.tmpl`, `run_onchange_after_tmux_symlinks.sh.tmpl`) are wrapped in `{{ if ne .chezmoi.os "windows" }}` guards so they render to empty on Windows (chezmoi skips empty scripts).
- **Windows bootstrap** — `home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl` installs packages via Chocolatey (`choco install -y`) and Winget, runs `mise install`, syncs Neovim plugins, and configures/starts YASB autostart via `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. `home/.chezmoiscripts/run_onchange_after_choco_review_windows.ps1.tmpl` runs interactive Chocolatey drift review after overlay changes when `bash` is available. Runs only on Windows. The elevated block does **not** skip Chocolatey/WSL when `CI` is set (same code path as interactive runs; `windows-elevation.ps1.tmpl` still avoids UAC in CI by running the block in-process). Package lists live in `home/.chezmoidata/chocolatey/*.yaml` and `home/.chezmoidata/winget/*.yaml` as `overlays.<name>.packages` (same merge idea as `home/.chezmoidata/brew/`: overlay dicts merge; lists under each overlay are concatenated in lexical overlay name order).
- **`install.ps1.tmpl`** at the repo root is the Windows installer template equivalent of `install.sh.tmpl`: installs Chocolatey, chezmoi, and git, then runs `chezmoi init --apply`.
- **WezTerm** — `home/dot_config/wezterm/wezterm.lua` (→ `~/.config/wezterm/wezterm.lua`). Windows terminal emulator with kitty graphics protocol support. Ignored on non-Windows via `.chezmoiignore`.
- **OpenCode** — `home/dot_config/opencode/opencode.jsonc.tmpl` renders MCP and permission data from `home/.chezmoidata/mcps/*.yaml` and `home/.chezmoidata/agent-permissions/*.yaml`. Atlassian entries are gated by `conditions` in those overlays (for example `private: false`), so they are excluded on personal machines. Since Windows is always personal, this also covers Windows.
- **Package manager** — Windows uses Chocolatey (`choco`), not winget or scoop.
- **When adding new configs**, decide if the target is cross-platform, Unix-only, or Windows-only, and update `home/.chezmoiignore` accordingly.
- **When adding new chezmoiscripts**, bash scripts (`.sh.tmpl`) must be guarded with `{{ if ne .chezmoi.os "windows" }}` and PowerShell scripts (`.ps1.tmpl`) with `{{ if eq .chezmoi.os "windows" }}` so they render to empty on the wrong OS.
- **WSL** — The Windows bootstrap script provisions WSL Ubuntu non-interactively via cloud-init. The cloud-init YAML lives in `home/.chezmoidata/wsl/00-ubuntu-user-data.yaml` as `windowsWsl.ubuntuCloudInitUserData` (static data; `.chezmoi.toml` `[data] wsl` remains the boolean “running inside WSL”). On **first** WSL setup only, `~/.local/share/chezmoi` is created with **`cp -a` from the Windows chezmoi source** on `/mnt/<drive>/...` (see `home/.chezmoitemplates/wsl-windows-chezmoi-source-mount-path.tmpl`: maps `.chezmoi.sourceDir`). If that directory already exists, Windows scripts and cloud-init **do not** remove or overwrite it — ongoing dotfile work is done inside WSL. Shared Windows WSL script inputs (`profile.windows.wslUser` + mount path) are built in `home/.chezmoitemplates/wsl-windows-script-context.json.tmpl` (`toJson` / `fromJson`) for `run_onchange_after_bootstrap_windows.ps1.tmpl` and `run_after_95_wsl_ensure_windows.ps1.tmpl`. Set `profile.windows.wslUser` in `home/.chezmoidata/profile.yaml` (required on Windows; empty fails apply for WSL/bootstrap scripts). Scripts substitute `__WSL_CHEZMOI_SOURCE__` and `__WSL_USER__` into that blob at apply time, write `~/.cloud-init/Ubuntu.user-data`, install Ubuntu with `--no-launch`, and wait for cloud-init. Inside WSL, `chezmoi.os` is `"linux"` so the full Unix config stack (zsh, brew, tmux, etc.) applies without modification.

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

## Finicky config changes

After applying changes to the Finicky config (`~/.config/finicky.js`), reload it by:

1. `killall Finicky || true`
2. `open -a Finicky`
3. Close the foreground window manually (AppleScript window close is not available without assistive access)

Finicky's built-in auto-reload does NOT work when the config is managed by chezmoi. Chezmoi replaces the file with a new inode on every write; Finicky's fsnotify watcher (kqueue on macOS) tracks by inode and loses the watch when this happens. A restart is always required.

---

## Rancher Desktop / Docker (Windows)

- Rancher Desktop provides the Docker daemon on Windows via a WSL2 backend (`rancher-desktop` distro).
- Container engine must be **`moby`** (not containerd) for the `docker` CLI to work.
- Docker CLI and `rdctl` live at `C:\Program Files\Rancher Desktop\resources\resources\win32\bin\`.
- Settings file: `%LOCALAPPDATA%\rancher-desktop\settings.json` (schema version in `version` field).
- `rdctl set` covers engine and Kubernetes flags; WSL integration (`WSL.integrations.<distro>`) must use `rdctl api -X PUT --input <file> /v1/settings` with a `version` field.
- `home/.chezmoiscripts/run_after_96_rancher_desktop_windows.ps1.tmpl` starts RD, waits for the Docker daemon pipe (`\\.\pipe\docker_engine`), and enables WSL integration for Ubuntu.
- The script runs after WSL ensure (95) so Ubuntu is available for integration.
- If the backend crashes (WSL distros show Stopped while UI shows online), fix with: `rdctl shutdown --wait && wsl --shutdown && rdctl start --container-engine.name moby`.

---

## Komorebi (Windows tiling)

Komorebi is the Windows tiling WM (it replaced GlazeWM). Config is chezmoi-managed at `home/dot_config/komorebi/komorebi.json` (→ `~/.config/komorebi/komorebi.json`); keybindings at `home/dot_config/whkdrc` (→ `~/.config/whkdrc`); a launcher at `home/dot_config/komorebi/start.ps1` is wired into the HKCU Run key by the Windows bootstrap. Gotchas that have bitten us:

- **`KOMOREBI_CONFIG_HOME` must be set.** Without it, komorebi looks for `komorebi.json` in `$USERPROFILE` and silently runs with built-in defaults. `start.ps1` sets it before launch; the bootstrap also sets it as a User env var so interactive `komorebic` works.
- **Komorebi is default-ignore for many app categories**, unlike GlazeWM which was default-manage. For Discord/Vivaldi-style "obvious" windows komorebi tiles them out of the box, but terminals, MSIX/UWP apps, and Electron apps with layered rendering need explicit rules. The community rulebook is `komorebic fetch-asc` — fetches `applications.json` covering hundreds of common apps; point `komorebi.json`'s `app_specific_configuration_path` at it.
- **Layered windows (`WS_EX_LAYERED`) are skipped before any `manage_rules` fires.** Diagnose by checking exstyle (PowerShell + `GetWindowLong`); fix by adding the exe to `layered_applications` *in addition to* `manage_rules`. **Gotcha: `layered_applications` is per-exe, not per-window.** If an app has a non-layered main window plus a layered popup under the same exe (e.g. Claude Desktop's main window vs the Ctrl+Alt+Space launcher), adding the exe causes komorebi to tile the popup too. Leave the exe out — komorebi manages the non-layered main via `manage_rules` and auto-skips the layered popup. Win32 file/save dialogs (class `#32770`) belong in `ignore_rules` once, globally — they're modal child windows komorebi shouldn't touch in any app.
- **Colour format in `komorebi.json` is `{r, g, b}` objects.** Hex strings (`"0xFFBC8D"`) and integer COLORREFs are both rejected by the `Colour` enum.
- **Never `Stop-Process -Force` on komorebi.** It leaves a stuck `%LOCALAPPDATA%\komorebi\komorebi.sock` AF_UNIX file that Windows refuses to delete via *any* API (Remove-Item, fsutil reparsepoint delete, WSL rm, error 1920) and the file even survives reboots. Subsequent komorebi launches then fail with error 1920 at `window_manager.rs:143`. Always `komorebic stop` instead. If a stuck sock already exists, the only workaround is to `Rename-Item` the parent dir (`%LOCALAPPDATA%\komorebi` → `komorebi.stale.<N>`) so komorebi recreates a fresh one.
- **`is_paused: true` silently no-ops every command.** Before deep debugging of "commands do nothing", check `komorebic state | ConvertFrom-Json | Select-Object is_paused`. `komorebic toggle-pause` flips it.
- **`komorebic` IPC fails from non-interactive/background shells** with WSAEINVAL (error 10022) on the AF_UNIX socket — even when the same komorebi instance happily talks to commands from a real interactive PowerShell. Don't waste time debugging from agent shells; have the user run commands themselves.
- **Komorebi can't launch from a non-interactive session** either — it fails with "failed call to AllowSetForegroundWindow after 5 retries". The Run key (logon-time) and a user-launched PowerShell window both work; agent-spawned PowerShell doesn't.
- **whkd quirks:** key name is `return`, not `enter`. `.shell cmd` is more reliable than `.shell pwsh` because pwsh isn't always on the PATH whkd inherits from `start.ps1`. Under `.shell cmd`, chain commands with `&&` (or `&`) — cmd doesn't treat `;` as a separator, so PowerShell-style `cmd1; cmd2` silently parses `;` as a literal arg. whkd has no modal binding modes (GlazeWM's `alt+r` resize mode has no direct equivalent — use direct chords like `alt+ctrl+hjkl`).
- **PowerToys FancyZones competes** with komorebi for foreground/window management and can prevent komorebi launching. Disable the FancyZones module in PowerToys before relying on komorebi.
- **`komorebic reload-configuration` reloads `komorebi.json`. whkd has no live reload** — restart it (`Stop-Process whkd` then `Start-Process`) to pick up `whkdrc` changes. The chezmoi `run_onchange_after_komorebi_reload_windows.ps1.tmpl` script does both.

---

## mise on Windows

- **Chocolatey `mise` package omits `mise-shim.exe`.** Without it, mise falls back to "file" shim mode (cmd wrappers under `~/AppData/Local/mise/shims/`). File shims work from a shell but cannot return a real binary path to non-shell parents (MCP servers, IDE integrations), which fail with `cannot find binary path`. Resolution rule: mise looks for `mise-shim.exe` next to `mise.exe` or on `PATH`; otherwise it falls back to file mode. See https://github.com/jdx/mise/discussions/7998.
- **The fix is hash-pinned to the choco install layout.** `home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl` (elevated block, after `choco install`) downloads `mise-v<version>-windows-x64.zip` from the matching GitHub release and drops `mise-shim.exe` at `C:\ProgramData\chocolatey\lib\mise\tools\x64\`. Shared logic lives in `home/.chezmoitemplates/windows-mise-shim-placement.ps1.tmpl`.
- **Recovery after choco upgrades:** `home/.chezmoiscripts/run_after_97_mise_shim_windows.ps1.tmpl` is an always-run guard that fires after `run_after_90_package_updates_windows.ps1.tmpl`. If a `choco upgrade` replaced `mise.exe` and dropped the shim, the guard re-places it and runs `mise reshim` so per-tool shims convert back to binary shims. Fast no-op when the shim is present.
- **Elevated-block stderr gotcha (PS 5.1).** `Invoke-ElevatedWithLog` spawns `powershell.exe` (Windows PowerShell 5.1, not pwsh). Under `$ErrorActionPreference = 'Stop'`, PS 5.1 promotes native-command stderr into a terminating error. `mise --version` emits a `WARN ... version available` line to stderr when a newer release exists, so the placement template uses `[System.Diagnostics.ProcessStartInfo]` instead of `& mise --version 2>$null` to read stdout cleanly. Outer `mise reshim` calls run under `pwsh` (PS 7+) and are unaffected.
- **`npm:@anthropic-ai/claude-code` needs the `@anthropic-ai/claude-code-win32-*` optional dependency.** If that package is missing, `install.cjs` never drops `bin/claude.exe` and you may only see `claude.exe.old.<timestamp>`; the generated `claude.ps1` shim then fails with “not recognized”. Fix: `mise uninstall 'npm:@anthropic-ai/claude-code@<version>' -y` then `mise install` (or `mise install npm:@anthropic-ai/claude-code@latest`) so npm re-fetches optional deps.

---

## Continuous maintenance (meta-rule)

- After every substantive conversation, review whether this file needs updating.
- Add convention rules when the user establishes a new pattern or corrects agent behaviour.
- If stderr shows `mise WARN missing: ...` during commands in this repo, run `mise install` before continuing.
- Before ending a session, check that the git working directory is clean. If it is not clean, either commit/apply/push when appropriate, or ask the user via the question tool when intent is unclear.
- Never remove rules without explicit user confirmation.
- Keep this file concise — if it grows beyond ~200 lines of rules (excluding vault context), propose splitting into topic-specific files.
- When in doubt, append a new rule rather than silently adopting a convention that isn't written down.
