# Agent guide: chezmoi dotfiles repo

This repo is a **chezmoi** dotfiles repository. It defines config files and scripts that are applied to the user’s home directory via `chezmoi apply`.

---

## Important: use the official docs

**Do not guess** about chezmoi behavior, naming, or structure. When in doubt:

- **Consult the official docs:** [https://www.chezmoi.io/](https://www.chezmoi.io/)
- Use the site search and reference sections for: source state attributes, special files/directories, scripts, templating, target types, and application order.
- Prefer [chezmoi user guide](https://www.chezmoi.io/user-guide/setup/) and [reference](https://www.chezmoi.io/reference/concepts/) over inferring from this file alone.

This document summarizes how *this* repo is laid out and points to official concepts; it is not a substitute for the chezmoi docs.

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
- The working tree (git repo) is the parent of that path; `install.sh`, `.macos`, `.gitignore`, and `README.md` live at repo root and are **not** part of the source state.

### Naming: source state attributes

Paths under `home/` use chezmoi’s **source state attributes** (prefixes/suffixes). Only the main ones used in this repo are listed here; the full table and order rules are in the reference.

| Prefix       | Effect |
|-------------|--------|
| `dot_`      | Target name gets a leading dot (e.g. `dot_gitconfig` → `~/.gitconfig`). |
| `private_`  | Target has no group/world permissions (e.g. `private_dot_gnupg`). |
| `executable_` | Target is executable (e.g. `executable_7zw` → `~/.7zw`). |
| `run_`      | Content is a script run on apply. |
| `run_once_` | Script run once per content (by hash). |
| `before_` / `after_` | With `run_*`: run before or after updating files. |

| Suffix   | Effect |
|----------|--------|
| `.tmpl`  | Content is a [text/template](https://pkg.go.dev/text/template) (see [Templating](https://www.chezmoi.io/user-guide/templating/)). |

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

Deleting a file from the chezmoi source does **not** remove it from the target (`~/`). Chezmoi only removes targets when explicitly told to via `.chezmoiremove` or the `remove_` prefix. If you delete a source file and run `chezmoi apply`, the deployed target is left behind as an unmanaged file. To fully remove a managed file:

- Delete the source file from `home/`.
- Run `chezmoi apply` (this will not touch the target).
- Manually delete the deployed file from `~/` (e.g. `rm ~/.scripts/kitten`).

---

## Repo-specific conventions

- **Zsh** – Primary config under `home/dot_config/zsh/`: `dot_zshrc`, `dot_zshenv`, `dot_zprofile`, `dot_zplugins`, `dot_zshrc.d/`, `dot_zfunctions/`, `dot_p10k.zsh`. Top-level `home/dot_zshenv` and `home/dot_profile` set `ZDOTDIR` / `XDG_CONFIG_HOME` and are sourced by the shell.
- **Neovim** – `home/dot_config/nvim/` (LazyVim-style: `init.lua`, `lua/config/`, `lua/plugins/`).
- **OpenCode** – `home/dot_config/opencode/opencode.jsonc` (→ `~/.config/opencode/opencode.jsonc`). This is the global OpenCode config: model, MCP servers, permissions, etc. Edit it here when updating OpenCode settings.
- **OpenCode global agent rules** – `home/dot_config/opencode/AGENTS.md` (→ `~/.config/opencode/AGENTS.md`). Universal agent rules that apply across all OpenCode sessions and projects. Edit the source here and run `chezmoi apply`. Never edit `~/.config/opencode/AGENTS.md` directly.
- **Other config** – `home/dot_config/` includes tmux, mise, finicky; `home/private_dot_gnupg/` for GnuPG (private permissions).
- **Executable** – `home/dot_scripts/executable_brew-review` (→ `~/.scripts/brew-review`) is the Homebrew drift review script. `home/dot_scripts/executable_7zw` (→ `~/.scripts/7zw`) is a 7-zip wrapper. Both live in `dot_scripts/` — not `dot_zfunctions/` (see Brew section below).
- **Bootstrap** – `home/.chezmoiscripts/run_once_before_bootstrap.sh.tmpl` runs once before other updates (install deps, brew bundle, oh-my-zsh, mise, etc.). It is OS-aware (darwin/linux) and sets Codespaces overrides when `codespaces` is true.
- **Root-level (not in source state)** – `install.sh` runs `chezmoi init --apply --source=...` to bootstrap; `.macos` holds macOS defaults; `.gitignore` excludes local/private artifacts (e.g. `*.local.*`, vim swap/undo). Do not add ignored patterns to the source state.

---

## Homebrew management

- **`home/Brewfile`** and **`home/Brewfile.ignore`** are source-dir only — listed in `home/.chezmoiignore` and never applied to `~/`.
- **`home/.chezmoiscripts/run_onchange_after_bootstrap.sh.tmpl`** – runs `brew bundle install` when `Brewfile` changes (uses `{{ include "Brewfile" | sha256sum }}` in a comment to trigger).
- **`home/.chezmoiscripts/run_onchange_after_brew_review.sh.tmpl`** – calls `brew-review` via `bash "$CHEZMOI_SOURCE_DIR/dot_scripts/brew-review" || true` when `Brewfile` changes.
- **`$CHEZMOI_SOURCE_DIR` in script context** points to `home/` (the chezmoiroot), so paths within scripts use `dot_scripts/brew-review` not `.scripts/brew-review`.
- **Brewfile conventions:** alphabetised within each section (brew, cask, mas); commented-out entries sorted inline with active lines by package name; darwin-only entries use `if OS.mac?` conditionals; Codespaces-irrelevant entries (GUI apps, Docker, cloud CLIs, decorative tools, packages pre-installed in Codespaces like `gh`, `git`, `zsh`) use `unless ENV["CODESPACES"]`; entries are never regenerated wholesale.
- **brew-review add action:** appends the new entry then calls `_sort_brewfile` (a Python-based sort function embedded in the script) to re-sort the whole file in place. The sort preserves the file header, keeps section order, and sorts active and commented-out lines together by package name (case-insensitive).
- **`brew-review` must NOT be in `dot_zfunctions/`** — autoloaded zsh functions run in the current shell, so `exit` kills the terminal. It lives in `dot_scripts/` instead, deployed to `~/.scripts/` which is on PATH via the `path` array in `dot_config/zsh/dot_zshenv`.
- **PATH for `~/.scripts`** – added to the `path` array with `(N)` glob qualifier in `dot_config/zsh/dot_zshenv`, not as a raw `$PATH` string export.
- **When removing a tap:** uninstall all installed formulae/casks from that tap first, then untap. `brew tap-info --json` returns all tap contents — filter with `brew list --formula` / `brew list --cask` to get only installed ones.
- **`brew update` in scripts** must NOT have `|| true` — failures are real errors.

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

## Continuous maintenance (meta-rule)

- After every substantive conversation, review whether this file needs updating.
- Add convention rules when the user establishes a new pattern or corrects agent behaviour.
- Never remove rules without explicit user confirmation.
- Keep this file concise — if it grows beyond ~200 lines of rules (excluding vault context), propose splitting into topic-specific files.
- When in doubt, append a new rule rather than silently adopting a convention that isn't written down.
