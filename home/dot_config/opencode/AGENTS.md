# Global agent rules

These rules apply to **all** OpenCode sessions, across every project.

---

## Two-level rule system

OpenCode loads rules from two locations:

| Level | File | Scope |
|-------|------|-------|
| **Global** | `~/.config/opencode/AGENTS.md` | Every session, every project |
| **Project** | `AGENTS.md` in the project root (or nearest ancestor) | That project only |

Use `~/.config/opencode/AGENTS.md` for rules that should apply universally — personal preferences, workflow conventions, and cross-cutting principles.

Use a project-level `AGENTS.md` for rules specific to that codebase: language conventions, repo layout, build commands, etc.

---

## Prefer docs over guessing

When uncertain about how a tool, API, framework, or CLI behaves — fetch the official documentation rather than inferring or guessing. Incorrect assumptions cause harder-to-debug problems than a short lookup. This applies even when you have partial knowledge: verify edge cases from the source.

---

## Continuous maintenance (meta-rule)

- After every substantive conversation, review whether `~/.config/opencode/AGENTS.md` or the relevant project `AGENTS.md` needs updating.
- Add a rule when a user corrects agent behavior or establishes a new pattern — write it down so the next session benefits.
- Never remove rules without explicit user confirmation.
- Never silently adopt a convention that isn't written down.
- Keep `~/.config/opencode/AGENTS.md` concise. If it grows unwieldy, propose splitting into topic files.

---

## Global memory and local memory

The user refers to `~/.config/opencode/AGENTS.md` as **global memory**. When asked to "commit something to global memory":

1. Edit the chezmoi source at `~/.local/share/chezmoi/home/dot_config/opencode/AGENTS.md`
2. Run `chezmoi apply`

Never edit `~/.config/opencode/AGENTS.md` directly — it is managed by chezmoi and will be overwritten.

The user refers to the `AGENTS.md` in the current project root (or nearest ancestor) as **local memory**. When asked to "commit something to local memory", edit that file directly.

The same chezmoi rule applies to all dotfiles under `~/.config/` — always edit the source in `~/.local/share/chezmoi/` and apply from there.

For rules specific to the chezmoi dotfiles repo itself, edit `~/.local/share/chezmoi/AGENTS.md` instead.

---

## Writing style

- Never use em dashes (---, &mdash;, or the Unicode character —). Use a comma, colon, or restructure the sentence instead. This applies at the point of writing — do not generate em dashes and fix them later. Treat this as a hard constraint during composition, not a post-hoc linting step.

---

## Daily note logging

When something is achieved during a session (a task completed, a ticket updated, a document published, etc.), check whether today's daily note exists in Obsidian before asking. Only ask if the note already exists. Use the `question` tool to ask — not plain text. Only add it if they confirm. Use the Obsidian Tasks format for action items and plain bullets for logged achievements, following vault conventions.

---

## Problem-solving attitude

Never suggest the user accept a limitation, take a shortcut, or move on when a proper solution may exist. Keep investigating until the problem is actually solved. Suggesting workarounds as a final answer is not acceptable.

---

## Atlassian Jira — writing ticket content

When writing content to Jira tickets via the Atlassian MCP (descriptions, comments, etc.):

- Reference other Jira tickets using the plain key format: `KEY-123` (e.g. `SEC-105`, `ONW-476`). Jira auto-resolves bare keys to smart links in the rendered UI.
- Do **not** use the `JIRA:KEY-123` prefix — that is an Obsidian-specific convention for the Jira plugin and will appear as literal text in Jira.
- Jira Cloud uses Atlassian Document Format (ADF) for rich text. When passing content via MCP tools, prefer plain text or ADF-structured input as required by the tool — do not use Confluence/Jira wiki markup (e.g. `h2.`, `||`, `{code}`) unless the tool explicitly expects it.
- In Obsidian notes, continue to use `JIRA:KEY-123` as per vault conventions.

---

## Commit discipline

Before committing, run `git diff --staged` and make an objective assessment of whether the change is both atomic and in-scope based on the context of the request. Do not commit unrelated changes that happened to be modified in the working tree.
