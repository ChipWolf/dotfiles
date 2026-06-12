---
name: agent-audit
description: Capture each installed coding-agent client's fresh-chat prompt overhead (Claude Code, OpenCode, Codex, pi, Hermes Agent, Cursor) and report system-only plus first-turn request sizes in characters and approximate tokens. Use when asked to audit, measure, or compare agent prompt overhead.
---

## On load

Immediately run `./audit.sh --breakdown` from the skill directory and present the results. Do not ask the user if they want to run it — just run it.

When presenting output:
- Print the unified breakdown table as a **markdown table** (not a code block).
- Print the summary rows (CLIENT/VERSION/SYS/FIRST) as a **markdown table**.
- Print the top-5 discrepancies as prose or a list — do not summarise or omit rows from either table.

## Purpose

Reproduce the prompt overhead that each installed coding-agent client sends on the first turn of a new chat, then report both the system-only size and the fuller first-turn request size in characters and tokens. Useful for cost/context budgeting, comparing tool overhead, and watching for skill/AGENTS.md bloat over time.

## Run it

From the skill directory, or wherever the dir is mounted:

```sh
./audit.sh                 # All detected clients, summary table to stdout
./audit.sh --raw           # Also write captured prompts under $AGENT_AUDIT_OUT_DIR
./audit.sh --breakdown     # Also print per-category composition tables (base/tools/MCP/skills/memory)
./audit.sh claude codex    # Only the named clients (claude, opencode, codex, pi, hermes, cursor)
```

Defaults:

- Each client is invoked from a throwaway cwd under `$TMPDIR` so AGENTS.md/CLAUDE.md picked up from ancestors do not pollute the baseline.
- Raw captures go to `${AGENT_AUDIT_OUT_DIR:-$TMPDIR/agent-audit-<timestamp>}/<client>.txt`.
- Token counts are a `chars / 4` estimate. Replace with `tiktoken` if you need exactness.

## Per-category breakdown (`--breakdown`)

The summary table reports both system-only size (`SYS_*`) and fuller first-turn request overhead (`FIRST_*`; see "What the size figures cover"). `--breakdown` adds two further views rendered by `lib/breakdown-unified.mjs`:

1. **Unified table** — one column per agent, mapping per-client raw category labels to a shared canonical set so rows align across agents.
2. **Top-5 discrepancies** — the five canonical categories (or the overall total) with the largest absolute spread across agents, with per-agent values and a plain-English note.

Per-client raw categories and source files:

| Client   | Source read              | Raw categories surfaced                                                             |
|----------|--------------------------|-------------------------------------------------------------------------------------|
| Claude   | `claude-request.json`    | base prompt (system), built-in tools, MCP tool definitions, memory (CLAUDE.md chain), skills catalogue, MCP server instructions, reminders & user msg |
| OpenCode | `opencode-prompt.json` + `opencode-request.json` | base prompt, environment (`<env>`), memory (AGENTS.md), skills (`<available_skills>`), context-window protection, MCP tools (mcpproxy, split from built-in tools by `mcpproxy_*` prefix on `t.function.name`), provider tool schemas |
| Codex    | `codex-prompt-input.json` + `codex-request.json` | wire base instructions, permissions instructions, skills (`<skills_instructions>`), provider tool schemas |
| pi       | `pi-system.txt` + `pi-request.json` | base prompt, memory (project context from `<project_context>` block when run from a project dir), tools list, guidelines & pi docs, environment, provider tool schemas |
| Hermes   | `hermes-request.json`    | base prompt (preamble), skills (`<available_skills>`), memory (project context injected from cwd), provider tool schemas |

The `FIRST_*` columns now use captured or locally-rendered first-turn request material consistently: prompt text plus provider tool/function schemas. `SYS_*` preserves the narrower local system/developer text for debugging client prompt changes. Categorization is marker-driven (XML tags, section headers); if a client reorders or renames a section, the affected category falls back into "base prompt" rather than erroring — watch for an implausibly large base bucket after a CLI upgrade.

## Capture mechanisms

Each client requires a different trick because none expose "dump my system prompt" directly:

| Client       | Method                                                              | Helper file                  |
|--------------|---------------------------------------------------------------------|------------------------------|
| Claude Code  | Loopback HTTP server bound to a random port via `ANTHROPIC_BASE_URL` | `lib/claude-loopback.mjs`    |
| OpenCode     | Throwaway TS plugin for system text + OpenAI-compatible loopback provider for the actual build-agent request | `lib/opencode-plugin.ts`, `lib/openai-loopback.mjs` |
| Codex        | Built-in `codex debug prompt-input` for system text + temporary `CODEX_HOME` custom provider pointed at loopback | `lib/openai-loopback.mjs` |
| pi           | Throwaway `PI_CODING_AGENT_DIR` with a local extension (`lib/pi-loopback-ext.mjs`) that overrides the built-in `anthropic` provider `baseUrl`; pi invoked with `-p hi --approve`; captures Anthropic `/v1/messages` via the same loopback as Claude Code | `lib/pi-dump.mjs` (SYS_* only), `lib/pi-loopback-ext.mjs`, `lib/claude-loopback.mjs` |
| Hermes       | Temporary `HERMES_HOME` dir with `config.yaml` pointing at loopback; one-shot via `hermes chat -q "hi"`; OpenAI chat/completions format (non-streaming) | `lib/openai-loopback.mjs` |
| Cursor       | Detect install only; no CLI ships on macOS today                    | none                         |

The `--breakdown` view is a post-processing pass over those captures, not a separate capture: `lib/breakdown-unified.mjs` re-reads each client's raw JSON from the out dir.

## What the size figures cover

- `SYS_CHARS` / `SYS_TOK`: the narrow system-role/developer payload the client exposes locally. This is useful for detecting base prompt changes.
- `FIRST_CH` / `FIRST_TOK`: the practical first-turn overhead that consumes context before the useful user task, including prompt text, tool/function schemas, MCP definitions where present, injected memory, skills catalogues, reminders, and the audit message when the client sends it in the captured request.
- Claude Code's `FIRST_*` includes the base system prompt, built-in tools, MCP tool definitions, resolved `~/.claude/CLAUDE.md` chain, skills catalogue, MCP server instructions, reminders, and the tiny audit user text.
- OpenCode's `FIRST_*` comes from a loopback OpenAI-compatible provider and skips the hidden title-generator request so it captures the build-agent request. Its `SYS_*` comes from the plugin system-transform hook.
- Codex's `FIRST_*` comes from a temporary custom provider in `CODEX_HOME` pointed at the loopback server. Its `SYS_*` still uses `codex debug prompt-input` for the local developer payload.
- pi `FIRST_*` is a real wire capture via Anthropic `/v1/messages` loopback. The throwaway `PI_CODING_AGENT_DIR` contains only the loopback extension and a dummy auth key; skills appear if pi's globally-installed packages inject them. The `SYS_*` column still uses `pi-dump.mjs` (local render, no network).
- pi walks ancestor directories for `AGENTS.md`/`CLAUDE.md` so its size scales with cwd. The throwaway cwd gives the baseline (no project context); rerun from a real project root to compare.
- OpenCode sends tools in OpenAI format (`{type: "function", function: {name, description, parameters}}`). The categorizer reads `t.function.name` (not `t.name`) to detect the `mcpproxy_*` prefix and separate those tools into the MCP tool definitions row. Non-mcpproxy tools go into Tool schemas.
- Hermes: uses `HERMES_HOME` env var to isolate to a temp dir so the real `~/.hermes/config.yaml` is never touched. Hermes injects AGENTS.md/CLAUDE.md from the cwd as "Project Context" — the throwaway cwd gives the baseline (no project context). The version is read from Python package metadata (`importlib.metadata`). Hermes sends non-streaming OpenAI chat/completions requests; the loopback detects `stream: undefined` and returns a plain JSON response (not SSE).

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
