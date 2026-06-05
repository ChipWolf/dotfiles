---
name: homebrew-management
description: Maintain Homebrew configuration in this chezmoi repo, including brew overlay data, Brewfile template generation, brew-review behavior, tap removal workflow, and env-var rules.
---

# Homebrew Management

Use this skill before changing Homebrew-related files in this repo.

## Scope

- `home/Brewfile.tmpl`
- `home/.chezmoidata/brew/*.yaml`
- `schemas/brew-overlays.schema.json`
- `home/Brewfile.ignore`
- `home/.chezmoiscripts/run_onchange_after_bootstrap.sh.tmpl`
- `home/.chezmoiscripts/run_onchange_after_brew_review.sh.tmpl`
- `home/dot_scripts/executable_brew-review`
- `docs/brew.md`
- Related Homebrew references in templates or scripts

## Key conventions

- Homebrew source of truth is overlay data in `home/.chezmoidata/brew/*.yaml`.
- `home/Brewfile.tmpl` renders all overlays found in `home/.chezmoidata/brew/*.yaml` (lexical file order).
- `home/Brewfile.ignore` is source-dir only, listed in `home/.chezmoiignore`, and not applied to `~/`.
- `run_onchange_after_bootstrap.sh.tmpl` renders `home/Brewfile.tmpl` at runtime and runs `brew bundle` against the rendered file.
- `run_onchange_after_brew_review.sh.tmpl` runs `brew-review` from `dot_scripts/brew-review`.
- In chezmoiscripts context, `$CHEZMOI_SOURCE_DIR` points at `home/` (the chezmoiroot), so paths should use `dot_scripts/...`.

## Overlay editing rules

- Keep entries organized by `type` for readability and minimize churn.
- Use one-line condition maps, for example:
  - `{ kind: os, op: is, value: mac }`
  - `{ kind: env, name: CODESPACES, op: unset }`
  - `{ kind: env, name: PRIVATE, op: set }`
- Keep package notes as inline YAML comments on the `name` line.
- Keep disabled/optional packages as commented-out YAML blocks in the relevant overlay file.
- After editing overlay/template files, validate render output:
  - `chezmoi execute-template --file home/Brewfile.tmpl | ruby -c`

## Brewfile trust rule

- Declared `brew` and `cask` package names that include an explicit tap path (`owner/tap/name`) are implicitly trusted by `home/.chezmoiscripts/run_after_90_homebrew_update.sh.tmpl` before `brew update` runs.
- Trust should stay package-scoped (`brew trust --formula` / `--cask`), not whole-tap scoped, so Homebrew's tap trust enforcement only allows what the overlay declares.
- Do not add per-package trust flags to overlay YAML unless we need exceptions later.

## Brewfile env var rule

Homebrew adds a `HOMEBREW_` prefix to env vars in Brewfile Ruby evaluation:

- In scripts, set short env vars before `brew bundle`, for example `CODESPACES=1` or `PRIVATE=1`.
- In overlay data, use short env names (`CODESPACES`, `PRIVATE`).
- `home/Brewfile.tmpl` adds the `HOMEBREW_` prefix during render.
- In rendered Brewfile, vars appear as `ENV["HOMEBREW_CODESPACES"]` and `ENV["HOMEBREW_PRIVATE"]`.
- Do not set `HOMEBREW_FOO=1` before `brew bundle`, that becomes `ENV["HOMEBREW_HOMEBREW_FOO"]`.

## brew-review placement

- `brew-review` must stay in `dot_scripts/`, not `dot_zfunctions/`.
- `~/.scripts` is added to PATH via the `path` array in `home/dot_config/zsh/dot_zshenv`.
- `brew-review` add-flow must write to a selected overlay data file and re-render the declared bundle for in-session drift checks.

## Tap removal workflow

When removing a tap:

1. Identify installed formulae and casks from that tap.
2. Uninstall installed formulae and casks from that tap.
3. Untap after uninstalling.

Use tap metadata plus installed-package lists to avoid uninstalling packages that are not installed.

## Script safety

- Do not add `|| true` to `brew update` in scripts.
- Script failures during package management should be treated as real errors.
