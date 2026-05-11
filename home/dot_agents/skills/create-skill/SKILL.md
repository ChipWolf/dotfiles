---
name: create-skill
description: Author and maintain agent skills with valid frontmatter, correct placement, and global-memory integration. Use when asked to create, update, or document a skill workflow.
---

## Purpose

Create high-quality agent skills that are discoverable, accurate, and maintainable.

## Canonical references

Before writing or changing a skill, verify format and behavior from official docs:

- <https://opencode.ai/docs/skills/>
- Use existing skills in `~/.agents/skills/*/SKILL.md` as style references.

Do not invent frontmatter fields or naming rules.

## Required structure

Each skill must be:

1. One directory per skill name.
2. A `SKILL.md` file in that directory.
3. YAML frontmatter with:
   - `name` (required)
   - `description` (required)

Name constraints:

- Lowercase alphanumeric and hyphen only.
- 1 to 64 characters.
- Must match the containing directory name.

Description constraints:

- 1 to 1024 characters.
- Clearly state what the skill does and when to use it.

## Authoring workflow

1. Identify target location:
   - Universal skills (shared across all coding agents): `~/.local/share/chezmoi/home/dot_agents/skills/`
   - Tool-specific skills (e.g. OpenCode-only): `~/.local/share/chezmoi/home/dot_config/<tool>/skills/`
2. Create skill directory and `SKILL.md`.
3. Write concise instructions with concrete command patterns and guardrails.
4. Include a self-improvement loop section so the skill is updated when better steps are found.
5. If the skill introduces rules that belong in global memory, update `~/.local/share/chezmoi/home/dot_agents/AGENTS.md`.
6. Verify deployed files after `chezmoi apply`.

## Content quality checklist

- Use imperative, action-oriented steps.
- Keep instructions specific to operational behavior, not generic advice.
- Include remediation branches for expected failure modes.
- Keep terminology consistent across sections.
- Avoid unnecessary verbosity, keep the skill easy to scan.

## Guardrails

- For AGENTS.md edits, load and follow the `memory` skill first.
- Do not edit deployed files directly, update chezmoi source and apply.
- Do not remove existing memory rules unless explicitly requested.

## Self-improvement loop

After each skill-authoring task, capture any improvements in structure, validation, or memory-integration steps by updating this file: `home/dot_agents/skills/create-skill/SKILL.md`.
