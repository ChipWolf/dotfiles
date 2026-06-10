---
name: agent-audit
description: Capture each installed coding-agent client's fresh-chat prompt overhead (Claude Code, OpenCode, Codex, pi, Cursor) and report system-only plus first-turn request sizes in characters and approximate tokens. Use when asked to audit, measure, or compare agent prompt overhead.
---

## Purpose

Reproduce the prompt overhead that each installed coding-agent client sends on the first turn of a new chat, then report both the system-only size and the fuller first-turn request size in characters and tokens. Useful for cost/context budgeting, comparing tool overhead, and watching for skill/AGENTS.md bloat over time.

## Run it

From the skill directory, or wherever the dir is mounted:

```sh
./audit.sh                 # All detected clients, summary table to stdout
./audit.sh --raw           # Also write captured prompts under $AGENT_AUDIT_OUT_DIR
./audit.sh --breakdown     # Also print per-category composition tables (base/tools/MCP/skills/memory)
./audit.sh claude codex    # Only the named clients (claude, opencode, codex, pi, cursor)
```

Defaults:

- Each client is invoked from a throwaway cwd under `$TMPDIR` so AGENTS.md/CLAUDE.md picked up from ancestors do not pollute the baseline.
- Raw captures go to `${AGENT_AUDIT_OUT_DIR:-$TMPDIR/agent-audit-<timestamp>}/<client>.txt`.
- Token counts are a `chars / 4` estimate. Replace with `tiktoken` if you need exactness.

## Per-category breakdown (`--breakdown`)

The summary table reports both system-only size (`SYS_*`) and fuller first-turn request overhead (`FIRST_*`; see "What the size figures cover"). `--breakdown` adds a second view: how each prompt divides into named categories — the same "where do the bytes go" decomposition Cursor and Claude Desktop surface in their UIs (base prompt vs tool defs vs MCP vs skills vs memory). Implemented in `lib/categorize.mjs`, which re-reads the raw capture audit.sh already wrote into the out dir.

| Client   | Source read              | Categories surfaced                                                                 |
|----------|--------------------------|-------------------------------------------------------------------------------------|
| Claude   | `claude-request.json`    | base prompt (system), built-in tools, MCP tool definitions, memory (CLAUDE.md chain), skills catalogue, MCP server instructions, reminders & user msg |
| OpenCode | `opencode-prompt.json`   | base prompt, environment (`<env>`), memory (AGENTS.md), skills (`<available_skills>`), context-window protection |
| Codex    | `codex-prompt-input.json`| base prompt, permissions instructions, skills (`<skills_instructions>`)             |
| pi       | `pi-system.txt`          | base prompt, tools list, guidelines & pi docs, environment                          |

Important scope difference: **Claude has a much larger first-turn request than its system payload** because tool definitions, MCP definitions, memory, and skills live outside the base system string. The summary's `FIRST_*` columns and the Claude breakdown both surface that fuller overhead; `SYS_*` preserves the narrower system-only number for debugging client prompt changes. The OpenCode/Codex/pi breakdowns segment the same text used for both their `SYS_*` and `FIRST_*` columns (modulo byte-vs-char-length on multi-byte content). Categorization is marker-driven (XML tags, section headers); if a client reorders or renames a section, the affected category falls back into "base prompt" rather than erroring — watch for an implausibly large base bucket after a CLI upgrade.

## Capture mechanisms

Each client requires a different trick because none expose "dump my system prompt" directly:

| Client       | Method                                                              | Helper file                  |
|--------------|---------------------------------------------------------------------|------------------------------|
| Claude Code  | Loopback HTTP server bound to a random port via `ANTHROPIC_BASE_URL` | `lib/claude-loopback.mjs`    |
| OpenCode     | Throwaway TS plugin hooking `experimental.chat.system.transform`     | `lib/opencode-plugin.ts`     |
| Codex        | Built-in `codex debug prompt-input` (no network call)               | none                         |
| pi           | Node ESM importing `buildSystemPrompt` from pi's `dist/core/`        | `lib/pi-dump.mjs`            |
| Cursor       | Detect install only; no CLI ships on macOS today                    | none                         |

The `--breakdown` view is a post-processing pass over those captures, not a separate capture: `lib/categorize.mjs` re-reads each client's raw JSON/text from the out dir.

## What the size figures cover

- `SYS_CHARS` / `SYS_TOK`: the narrow system-role/developer payload the client exposes locally. This is useful for detecting base prompt changes.
- `FIRST_CH` / `FIRST_TOK`: the practical first-turn overhead that consumes context before the useful user task, including tool definitions, MCP definitions, injected memory, skills catalogues, reminders, and the audit message when the client sends it in the captured request.
- Claude Code's `FIRST_*` includes the base system prompt, built-in tools, MCP tool definitions, resolved `~/.claude/CLAUDE.md` chain, skills catalogue, MCP server instructions, reminders, and the tiny audit user text.
- OpenCode embeds `~/.config/opencode/AGENTS.md` verbatim and only references `~/.agents/AGENTS.md` by path, so its `SYS_*` and `FIRST_*` are currently the same.
- Codex inlines `<skills_instructions>` listing every SKILL.md under `~/.agents/skills` and `~/.codex/skills`, so its `SYS_*` and `FIRST_*` are currently the same.
- pi walks ancestor directories for `AGENTS.md`/`CLAUDE.md` so its size scales with cwd. The throwaway cwd gives the baseline; rerun from a real project root to compare.

## Caveats

- Claude Code: requires `node` on PATH. The loopback server replies with a minimal valid `/v1/messages` response; the `claude` CLI is then killed once the body is captured.
- OpenCode: the plugin uses an experimental hook (`experimental.chat.system.transform`). Watch the OpenCode changelog if this stops firing — replace the hook name and dump call as needed.
- Codex: `codex debug prompt-input` returns only the locally-built developer messages. The canonical "You are Codex…" preamble lives server-side on the Responses API and is not retrievable without intercepting the wire request.
- pi: directly imports from the mise-installed package path. If pi is reinstalled at a different version, the resolver reads `~/.local/share/mise/installs/npm-earendil-works-pi-coding-agent/<version>/` and adapts.
- Cursor: not installed on this host; the script reports "not installed" instead of fabricating a value.

## Self-improvement loop

After each use, run this loop before ending the task:

1. Check the output for friction patterns:
   - A row reports `0` chars with a `not captured` / `failed` note (a capture mechanism broke).
   - A client's version detection prints `unknown` (output stream or format changed).
   - A new client appears in `home/.chezmoidata/skills/*.yaml` or `home/.chezmoidata/mcps/*.yaml` that has no row in the table.
   - A char count drifts more than ~10% from the previous run without a known cause (skills catalogue or AGENTS.md edits, CLI upgrade).
   - Token estimate (`chars/4`) diverges noticeably from a real tokenizer count when one is available.
   - `${TMPDIR}/agent-audit-*` dirs accumulate after a non-`--raw` run (cleanup trap regressed).
   - With `--breakdown`, a client's "base prompt" category balloons to nearly 100% (a section marker was renamed/reordered by a CLI upgrade, so `categorize.mjs` stopped recognising it and dumped it into the remainder), or a breakdown table is missing for a client that captured successfully.
2. If a pattern appears, update this skill in chezmoi source:
   - `skills/agent-audit/SKILL.md` for instructions and the capture-method table.
   - `skills/agent-audit/audit.sh` for detection, invocation, or output changes.
   - `skills/agent-audit/lib/<client>-*.{mjs,ts}` for capture mechanism fixes.
   - `skills/agent-audit/lib/categorize.mjs` for `--breakdown` segmentation (section markers, category labels).
3. Keep updates concrete, command-level, and minimal. Do not generalise a one-CLI quirk into a global default.
4. Re-run `./audit.sh` to validate the fix, then re-run on the full client set to confirm no regression in the others.
5. If the breakage stemmed from a class of mistake worth remembering across sessions (not just this skill), load the `memory` skill and add a rule to global `AGENTS.md`.
