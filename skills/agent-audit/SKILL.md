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
| OpenCode | `opencode-prompt.json` + `opencode-request.json` | base prompt, environment (`<env>`), memory (AGENTS.md), skills (`<available_skills>`), context-window protection, provider tool schemas |
| Codex    | `codex-prompt-input.json` + `codex-request.json` | wire base instructions, permissions instructions, skills (`<skills_instructions>`), provider tool schemas |
| pi       | `pi-system.txt` + `pi-request.json` | base prompt, tools list, guidelines & pi docs, environment, provider tool schemas |

The `FIRST_*` columns now use captured or locally-rendered first-turn request material consistently: prompt text plus provider tool/function schemas. `SYS_*` preserves the narrower local system/developer text for debugging client prompt changes. Categorization is marker-driven (XML tags, section headers); if a client reorders or renames a section, the affected category falls back into "base prompt" rather than erroring — watch for an implausibly large base bucket after a CLI upgrade.

## Capture mechanisms

Each client requires a different trick because none expose "dump my system prompt" directly:

| Client       | Method                                                              | Helper file                  |
|--------------|---------------------------------------------------------------------|------------------------------|
| Claude Code  | Loopback HTTP server bound to a random port via `ANTHROPIC_BASE_URL` | `lib/claude-loopback.mjs`    |
| OpenCode     | Throwaway TS plugin for system text + OpenAI-compatible loopback provider for the actual build-agent request | `lib/opencode-plugin.ts`, `lib/openai-loopback.mjs` |
| Codex        | Built-in `codex debug prompt-input` for system text + temporary `CODEX_HOME` custom provider pointed at loopback | `lib/openai-loopback.mjs` |
| pi           | Node ESM importing `buildSystemPrompt` and tool definitions from pi's `dist/core/` | `lib/pi-dump.mjs`, `lib/pi-request-dump.mjs` |
| Cursor       | Detect install only; no CLI ships on macOS today                    | none                         |

The `--breakdown` view is a post-processing pass over those captures, not a separate capture: `lib/categorize.mjs` re-reads each client's raw JSON/text from the out dir.

## What the size figures cover

- `SYS_CHARS` / `SYS_TOK`: the narrow system-role/developer payload the client exposes locally. This is useful for detecting base prompt changes.
- `FIRST_CH` / `FIRST_TOK`: the practical first-turn overhead that consumes context before the useful user task, including prompt text, tool/function schemas, MCP definitions where present, injected memory, skills catalogues, reminders, and the audit message when the client sends it in the captured request.
- Claude Code's `FIRST_*` includes the base system prompt, built-in tools, MCP tool definitions, resolved `~/.claude/CLAUDE.md` chain, skills catalogue, MCP server instructions, reminders, and the tiny audit user text.
- OpenCode's `FIRST_*` comes from a loopback OpenAI-compatible provider and skips the hidden title-generator request so it captures the build-agent request. Its `SYS_*` comes from the plugin system-transform hook.
- Codex's `FIRST_*` comes from a temporary custom provider in `CODEX_HOME` pointed at the loopback server. Its `SYS_*` still uses `codex debug prompt-input` for the local developer payload.
- pi has no provider loopback in the audit yet; `FIRST_*` is rendered locally from pi's system prompt plus the active tool definitions, so it is comparable for prompt/tool overhead but not a wire capture.
- pi walks ancestor directories for `AGENTS.md`/`CLAUDE.md` so its size scales with cwd. The throwaway cwd gives the baseline; rerun from a real project root to compare.

## Caveats

- Claude Code: requires `node` on PATH. The loopback server replies with a minimal valid `/v1/messages` response; the `claude` CLI is then killed once the body is captured.
- OpenCode: the plugin uses an experimental hook (`experimental.chat.system.transform`). Watch the OpenCode changelog if this stops firing — replace the hook name and dump call as needed. The loopback capture uses a custom `@ai-sdk/openai-compatible` provider and skips OpenCode's title-generator request.
- Codex: `codex debug prompt-input` returns only the locally-built developer messages. The loopback capture surfaces the fuller Responses API request, including the wire `instructions` preamble and tool schemas.
- pi: directly imports from the mise-installed package path. If pi is reinstalled at a different version, the resolver reads `~/.local/share/mise/installs/npm-earendil-works-pi-coding-agent/<version>/` and adapts. The pi first-turn request is locally rendered rather than intercepted on the wire.
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
