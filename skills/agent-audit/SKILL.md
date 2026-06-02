---
name: agent-audit
description: Capture the system prompt of each installed coding-agent client (Claude Code, OpenCode, Codex, pi, Cursor) on a fresh chat and report sizes in characters and approximate tokens. Use when asked to audit, measure, or compare agent system prompts.
---

## Purpose

Reproduce the system prompt that each installed coding-agent client sends on the first turn of a new chat, then report how many characters and tokens each one weighs. Useful for cost/context budgeting, comparing tool overhead, and watching for skill/AGENTS.md bloat over time.

## Run it

From the skill directory, or wherever the dir is mounted:

```sh
./audit.sh                 # All detected clients, summary table to stdout
./audit.sh --raw           # Also write captured prompts under $AGENT_AUDIT_OUT_DIR
./audit.sh claude codex    # Only the named clients (claude, opencode, codex, pi, cursor)
```

Defaults:

- Each client is invoked from a throwaway cwd under `$TMPDIR` so AGENTS.md/CLAUDE.md picked up from ancestors do not pollute the baseline.
- Raw captures go to `${AGENT_AUDIT_OUT_DIR:-$TMPDIR/agent-audit-<timestamp>}/<client>.txt`.
- Token counts are a `chars / 4` estimate. Replace with `tiktoken` if you need exactness.

## Capture mechanisms

Each client requires a different trick because none expose "dump my system prompt" directly:

| Client       | Method                                                              | Helper file                  |
|--------------|---------------------------------------------------------------------|------------------------------|
| Claude Code  | Loopback HTTP server bound to a random port via `ANTHROPIC_BASE_URL` | `lib/claude-loopback.mjs`    |
| OpenCode     | Throwaway TS plugin hooking `experimental.chat.system.transform`     | `lib/opencode-plugin.ts`     |
| Codex        | Built-in `codex debug prompt-input` (no network call)               | none                         |
| pi           | Node ESM importing `buildSystemPrompt` from pi's `dist/core/`        | `lib/pi-dump.mjs`            |
| Cursor       | Detect install only; no CLI ships on macOS today                    | none                         |

## What the size figures cover

- **Just the system role payload.** Tool definitions (Claude Code: ~128 KB per request), first-turn `<system-reminder>` injections, and skill catalogues passed as separate `system`-role messages are explicitly excluded so the numbers stay comparable across clients.
- Claude Code's first-turn user message embeds the resolved `~/.claude/CLAUDE.md` chain plus 14 KB of skills metadata; that lives off the system prompt and is not measured here.
- OpenCode embeds `~/.config/opencode/AGENTS.md` verbatim and only references `~/.agents/AGENTS.md` by path.
- Codex inlines `<skills_instructions>` listing every SKILL.md under `~/.agents/skills` and `~/.codex/skills`.
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
2. If a pattern appears, update this skill in chezmoi source:
   - `skills/agent-audit/SKILL.md` for instructions and the capture-method table.
   - `skills/agent-audit/audit.sh` for detection, invocation, or output changes.
   - `skills/agent-audit/lib/<client>-*.{mjs,ts}` for capture mechanism fixes.
3. Keep updates concrete, command-level, and minimal. Do not generalise a one-CLI quirk into a global default.
4. Re-run `./audit.sh` to validate the fix, then re-run on the full client set to confirm no regression in the others.
5. If the breakage stemmed from a class of mistake worth remembering across sessions (not just this skill), load the `memory` skill and add a rule to global `AGENTS.md`.
