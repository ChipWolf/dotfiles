# Homebrew

Homebrew state in this repo is managed as structured data, not hand-edited Ruby.

## Source of truth

The Homebrew package model lives in:

- `home/.chezmoidata/brew/`

Each file defines one or more overlays under `brew.overlays.<overlay-id>.packages`.

Package entries use structured fields:

- `type`: `tap`, `brew`, `cask`, or `mas`
- `name`: package token
- `masId`: required for `mas`
- `conditions`: optional condition objects (os/env/tty)

Condition objects are one-line maps, for example:

- `{ kind: os, op: is, value: mac }`
- `{ kind: env, name: CODESPACES, op: unset }`
- `{ kind: env, name: PRIVATE, op: set }`
- `{ kind: tty, op: is, value: true }`

## Generation

Homebrew bundle content is rendered from:

- template: `home/Brewfile.tmpl`
- data: `home/.chezmoidata/brew/*.yaml`
- all overlays discovered in lexical filename order

This repo keeps only template and overlay data in git. Scripts render the
bundle at runtime for `brew bundle` and drift review.

The template prefixes env conditions with `HOMEBREW_` during render because Homebrew evaluates Brewfile entries in its own bundle context and exposes passed env vars with a `HOMEBREW_` prefix (for example, script `CODESPACES=1` becomes Brewfile `ENV["HOMEBREW_CODESPACES"]`).

Declared `brew` and `cask` entries whose names include an explicit tap path (`owner/tap/name`) are implicitly trusted by the Homebrew update script before `brew update` runs, using `brew trust --formula` or `brew trust --cask`. This trusts only the declared formulae/casks needed by the bundle, not the whole tap.

## Runtime usage

Bootstrap script:

- `home/.chezmoiscripts/run_onchange_after_bootstrap.sh.tmpl`

It renders `home/Brewfile.tmpl` to a temporary file, then runs `brew bundle`
against that file with short env vars:

- `CODESPACES=1` for Codespaces
- `PRIVATE=1` for private machines

Homebrew itself evaluates these as `ENV["HOMEBREW_CODESPACES"]` and `ENV["HOMEBREW_PRIVATE"]` inside Brewfile Ruby.

## brew-review

`brew-review` is an interactive drift-review helper:

- script: `home/dot_scripts/executable_brew-review`
- deployed path: `~/.scripts/brew-review`
- orchestration script: `home/.chezmoiscripts/run_onchange_after_brew_review.sh.tmpl`

It compares:

- installed set (`brew bundle dump`)
- declared set (runtime-rendered `home/Brewfile.tmpl`)
- ignore set (`home/Brewfile.ignore`)

For installed-but-undeclared packages, prompts:

- **add**: choose an overlay file, append a structured package entry there, then re-render the declared bundle
- **remove**: uninstall package
- **ignore permanently**: append key to `home/Brewfile.ignore`
- **skip**: no action

Installed formulae/casks from taps are removed before untapping.

## Validation

Source tests include `tests/source/brewfile.bats` which verify:

- rendered Brewfile is valid Ruby
- expected env-prefix and condition formatting semantics
