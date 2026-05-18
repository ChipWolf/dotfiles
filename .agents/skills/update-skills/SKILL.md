---
name: update-skills
description: Update declared agent skills for this chezmoi repo: edit the skills manifest, run the apply-time installer, and reconcile drift via skills-review. Use when editing home/.chezmoidata/skills/*.yaml, the skills install scripts, the local skills/ directory, or when reviewing drift with ~/.scripts/skills-review.
---

# Update Skills

Use this skill when changing declared agent skills in this repo.

## Source of truth

- Canonical manifest: `home/.chezmoidata/skills/*.yaml` (overlay-friendly map merge)
- Schema: `schemas/skills.schema.json`
- Local skill source root: `skills/` at repo root (not under `home/`, not chezmoi state)
- Unix install script: `home/.chezmoiscripts/run_onchange_after_skills.sh.tmpl`
- Windows install script: `home/.chezmoiscripts/run_onchange_after_skills_windows.ps1.tmpl`
- Drift-review tool: `home/dot_scripts/executable_skills-review` (deployed to `~/.scripts/skills-review`)
- Removal tombstones: entries in `home/.chezmoiremove`

Treat `home/.chezmoidata/skills/*.yaml` as the single source of truth.

## Canonical schema

Manifest top-level key is `skills` with sub-keys:

- `defaults` (optional)
  - `defaults.targets`: array of agent IDs to use when a source doesn't specify its own.
- `sources` (required map, keyed by source ID)
  - Each `sources.<sourceId>` value has **exactly one** of:
    - `path` — local source, relative to `{{ .chezmoi.workingTree }}` (the git working tree / repo root, NOT the chezmoi source dir which would put it under `home/`)
    - `repo` — GitHub shorthand (`org/repo`) or full git URL
  - Optional per-source overrides:
    - `targets`: narrows the agent list for this source
    - `skills`: selective install of named skills only

Source IDs are kebab-case: `^[a-z0-9][a-z0-9-]*$`.

Supported agent IDs: `claude-code`, `opencode`, `cursor`, `codex`, `pi`. Adding a new agent requires editing both the schema enum and the install scripts.

## Installation model

- The Unix install script uses **symlink mode** (default for `npx skills`).
- The Windows install script uses **`--copy` mode** (Windows symlinks require admin or developer mode).
- On Unix, one canonical copy of each skill exists on disk; per-agent paths are symlinks back to it. No file duplication across agents.
- The install scripts are **install-and-update only**. They NEVER remove. To remove, edit the manifest and run `~/.scripts/skills-review`.

## Editing rules

1. Use map-keyed source entries (matches the `mcps/`, `agent-permissions/`, etc. overlay convention).
2. Use overlays in separate files under `home/.chezmoidata/skills/` for personal/fork-specific additions; map keys deep-merge.
3. Exactly one of `path` or `repo` per source.
4. For local sources, `path` is relative to `{{ .chezmoi.workingTree }}` (the git working tree, e.g. `~/.local/share/chezmoi`), NOT `{{ .chezmoi.sourceDir }}` (which is the source state root, e.g. `~/.local/share/chezmoi/home`). The canonical local skills source lives at `skills/` at the repo root, outside chezmoi source state. For remote sources, prefer GitHub shorthand (`org/repo`) over full URLs unless you need a non-GitHub host.
5. Don't reintroduce a "universal" location at `~/.agents/skills/`. The CLI distributes per-agent paths directly; the universal convention has been abandoned for skills.
6. To remove a skill, delete it from the manifest **and** run `~/.scripts/skills-review` interactively. Apply alone never removes.

## Validation workflow

After manifest or script changes:

1. `chezmoi apply <changed-path>` for targeted application.
2. Read the resulting deployed files under each per-agent skills dir (`~/.claude/skills/`, `~/.codex/skills/`, etc.) and confirm expected entries are present.
3. On Unix, verify entries are symlinks back to `<workingTree>/<path>/<skill>` (use `readlink`).
4. On Windows, verify entries are real directories with the expected content (use `Get-ChildItem`).
5. Run `~/.scripts/skills-review` and confirm no false-positive drift is reported when the manifest matches the install state.

## Drift review (skills-review)

- Run `~/.scripts/skills-review` after editing the manifest to remove a source.
- Run it periodically to catch hand-installed skills (someone ran `npx skills add` outside the manifest).
- The tool is interactive; it won't run in non-tty contexts. Apply scripts never invoke it.

## Adding a new agent target

1. Add the agent ID to the `agentId` enum in `schemas/skills.schema.json`.
2. Confirm the agent is supported by the `vercel-labs/skills` CLI (`npx skills@latest list-agents`, or check the CLI's `agents.ts`).
3. Add it to `defaults.targets` in the manifest (or to per-source `targets`).
4. The install scripts iterate dynamically over `defaults.targets` and per-source `targets`; no script change required.
