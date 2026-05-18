---
name: dotfiles
description: Make changes to chezmoi-managed dotfiles: adding, modifying, or removing config files, scripts, and templates in the source state. Load this skill before touching anything under ~/.local/share/chezmoi/.
---

## Required first step

Before making any dotfiles change, read and follow:

- `~/.local/share/chezmoi/AGENTS.md`

That file is the canonical source for repo structure, chezmoi conventions, OS behavior, script rules, and safety constraints. Do not duplicate or override it here.

## Delegated repo skills

When the task touches these domains, load the specialized skill from `~/.local/share/chezmoi/.agents/skills/` instead of duplicating rules here:

- **Homebrew data, Brewfile template, brew-review:** `homebrew-management/SKILL.md`
- **MCP server overlays/templates:** `update-mcp-servers/SKILL.md`
- **Agent permission overlays/schema/rendering:** `update-agent-permissions/SKILL.md`

## Purpose of this skill

Use this skill as a dispatcher:

1. Read `AGENTS.md`.
2. Route to the relevant specialized skill(s) above.
3. Apply changes in `~/.local/share/chezmoi/home/`, then run validation expected by the selected skill(s).

## Repo-specific layout

- **Zsh:** `home/dot_config/zsh/` — `dot_zshrc`, `dot_zshenv`, `dot_zprofile`, `dot_zplugins`, `dot_zshrc.d/`, `dot_zfunctions/`, `dot_p10k.zsh`. Top-level `home/dot_zshenv` and `home/dot_profile` set `ZDOTDIR`/`XDG_CONFIG_HOME`.
- **Neovim:** `home/dot_config/nvim/` (LazyVim-style).
- **Universal agent rules:** `home/dot_agents/AGENTS.md` — edit here, not at `~/.agents/AGENTS.md`.
- **Universal agent skills:** `home/dot_agents/skills/` — shared across all coding agents.
- **OpenCode config:** `home/dot_config/opencode/opencode.jsonc.tmpl`.
- **OpenCode-specific rules:** `home/dot_config/opencode/AGENTS.md` — OpenCode-only rules and context-mode routing.
- **OpenCode data overlays:** `home/.chezmoidata/agent-permissions/` and `home/.chezmoidata/mcps/`.
- **WezTerm:** `home/dot_config/wezterm/wezterm.lua` — Windows only (ignored on non-Windows).
- **Scripts:** `home/dot_scripts/` — deployed to `~/.scripts/` which is on PATH.
