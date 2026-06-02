# OpenCode-specific agent rules

Read and apply the rules in `~/.agents/AGENTS.md` first. This file adds OpenCode-specific extensions.

---

## Subagents

When delegating to subagents at session close, run them in sequence: one at a time, wait for each to complete.

If an MCP-backed subagent fails with "file not found" but the user confirms the file exists, suspect the MCP server's root or vault config before retrying. Verify the underlying MCP can resolve the path (e.g., a stats or list-directory call) before re-dispatching. If the MCP is broken, fall back to direct filesystem tools.

---

## Session close

Ask the user before logging to the daily note. Never log proactively. Once the user has consented to logging, do not also ask them to approve the draft content; dispatch the subagent to append directly.

---

## Memory

For OpenCode-specific rules, update this file (source: `~/.local/share/chezmoi/home/dot_config/opencode/AGENTS.md`).
For universal rules, update `~/.agents/AGENTS.md` (source: `~/.local/share/chezmoi/home/dot_agents/AGENTS.md`).

Load the `memory` skill for all writes.

Never edit `~/.config/opencode/AGENTS.md` directly; it is chezmoi-managed.

---

## Custom commands and subtask isolation

- Treat custom commands with `subtask: true` as isolated subagent executions with no access to the current session context.
- Session-aware commands (retrospectives, reviews) should run in the current session, not as subtasks.
