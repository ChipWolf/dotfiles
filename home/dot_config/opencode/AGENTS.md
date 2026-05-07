# Global agent rules

These rules apply to every OpenCode session, across every project.

---

## Always active

These constraints are unconditional. Apply them without being asked.

- **No em dashes.** Use commas, colons, or restructure the sentence. Never generate `—`, `---`, or `&mdash;`.
- **Never guess schemas or APIs.** Read the authoritative source first (Go structs, official docs, or the project's own examples). Blog posts and AI-generated examples are not acceptable. If docs don't render, clone the repo and read the struct tags directly.
- **Clone repos to read source.** Never curl GitHub API endpoints or fetch raw URLs. `git clone` first, then read.
- **All Python through mise.** Never invoke `python`, `pip`, `uv`, or `uvx` directly. Load the `python-toolchain` skill before any Python work.
- **Never accept a limitation without investigating.** Keep working until the problem is actually solved. Suggesting workarounds as a final answer is not acceptable.
- **Don't say "Docker containers."** Docker is a brand name, not a container type. Write "containers" or "OCI images" in prose. Action references like `docker/login-action` are fine as-is.

---

## Skills and subagents

Load skills on-demand via the `skill` tool. Use subagents for delegated async work.

| Name                    | Type     | When to use                                                                       |
|-------------------------|----------|-----------------------------------------------------------------------------------|
| `memory`                | skill    | Before writing to any AGENTS.md file                                              |
| `dotfiles`              | skill    | Before any change to chezmoi-managed files                                        |
| `python-toolchain`      | skill    | Before any Python, pip, uv, or mise work                                          |
| `git-commit-push`       | skill    | For commit and push requests, including auth and non-fast-forward remediation     |
| `create-opencode-skill` | skill    | For creating or updating OpenCode skills with valid format and memory integration |
| `retrospective`         | skill    | After completing any non-trivial task                                             |
| `@daily-note`           | subagent | Logging achievements to today's Obsidian daily note (ask user first)              |

When delegating to subagents at session close, run them in sequence: one at a time, wait for each to complete.

If an MCP-backed subagent fails with "file not found" but the user confirms the file exists, suspect the MCP server's root or vault config before retrying. Verify the underlying MCP can resolve the path (e.g., a stats or list-directory call) before re-dispatching. If the MCP is broken, fall back to direct filesystem tools.

---

## Session close: mandatory

After every non-trivial task, load the `retrospective` skill and follow it before closing out.

Ask the user before logging to the daily note. Never log proactively. Once the user has consented to logging, do not also ask them to approve the draft content; dispatch the subagent to append directly.

---

## Memory

Global memory is `~/.config/opencode/AGENTS.md` (source: `~/.local/share/chezmoi/home/dot_config/opencode/AGENTS.md`).
Local memory is the `AGENTS.md` in the current project root (or nearest ancestor).

- Load `create-opencode-skill` before creating or modifying OpenCode skills.

Never edit `~/.config/opencode/AGENTS.md` directly; it is chezmoi-managed. Load the `memory` skill for all writes.

For rules specific to the chezmoi dotfiles repo itself, the target is `~/.local/share/chezmoi/AGENTS.md`.

When updating any memory file: review nearby rules for contradictions, duplication, and scope conflicts; reconcile in the same edit. Keep cross-cutting rules in global memory; keep project-specific rules in local memory.

---

## Git and commits

- Load `git-commit-push` for commit or push operations.
- Before committing, run `git diff --staged` and confirm the change is atomic and in-scope. Do not commit unrelated modifications.
- Commit message format: `type(scope): description`. Types: `feat`, `fix`, `chore`. Check `git log --oneline` to match repo style.

---

## Shell discipline

- Prefer the smallest atomic command that completes the immediate next step. Do not chain concerns across policy boundaries.
- Keep source edits, `chezmoi apply`, and git operations as separate commands unless a later step strictly depends on the previous one within the same concern.
- Destructive or policy-sensitive actions should be isolated so intent is easy to inspect.
- Do not check whether a directory exists before using it. Attempt the operation; create the directory if it fails.
- On Windows, when admin rights are required, launch elevated commands with `Start-Process -Verb RunAs` instead of failing back to manual instructions.

---

## Custom commands and subtask isolation

- Treat custom commands with `subtask: true` as isolated subagent executions with no access to the current session context.
- Session-aware commands (retrospectives, reviews) should run in the current session, not as subtasks.

---

## Toolchain

- When a CLI can be managed by `mise`, run it through `mise x -- <command>`. Do not invoke managed tools directly.
- When `chezmoi apply` triggers a brew bundle run (via an onchange script), treat it as fire-and-forget once the apply succeeds.
- If `chezmoi apply` fails because an unrelated template needs a secret (e.g. Bitwarden locked), apply only the file you need with `chezmoi apply <target-path>` to bypass the failing template.

---

<!-- BEGIN context-mode routing rules — synced from configs/opencode/AGENTS.md (npm:context-mode). Re-sync when bumping context-mode in mise. -->

# context-mode — MANDATORY routing rules

context-mode MCP tools available. Rules protect context window from flooding. One unrouted command dumps 56 KB into context.

## Think in Code — MANDATORY

Analyze/count/filter/compare/search/parse/transform data: **write code** via `context-mode_ctx_execute(language, code)`, `console.log()` only the answer. Do NOT read raw data into context. PROGRAM the analysis, not COMPUTE it. Pure JavaScript — Node.js built-ins only (`fs`, `path`, `child_process`). `try/catch`, handle `null`/`undefined`. One script replaces ten tool calls.

## BLOCKED — do NOT attempt

### curl / wget — BLOCKED
Shell `curl`/`wget` intercepted and blocked. Do NOT retry.
Use: `context-mode_ctx_fetch_and_index(url, source)` or `context-mode_ctx_execute(language: "javascript", code: "const r = await fetch(...)")`

### Inline HTTP — BLOCKED
`fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(` — intercepted. Do NOT retry.
Use: `context-mode_ctx_execute(language, code)` — only stdout enters context

### Direct web fetching — BLOCKED
Use: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)`

## REDIRECTED — use sandbox

### Shell (>20 lines output)
Shell ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`.
Otherwise: `context-mode_ctx_batch_execute(commands, queries)` or `context-mode_ctx_execute(language: "shell", code: "...")`

### File reading (for analysis)
Reading to **edit** → reading correct. Reading to **analyze/explore/summarize** → `context-mode_ctx_execute_file(path, language, code)`.

### grep / search (large results)
Use `context-mode_ctx_execute(language: "shell", code: "grep ...")` in sandbox.

## Tool selection

0. **MEMORY**: `context-mode_ctx_search(sort: "timeline")` — after resume, check prior context before asking user.
1. **GATHER**: `context-mode_ctx_batch_execute(commands, queries)` — runs all commands, auto-indexes, returns search. ONE call replaces 30+. Each command: `{label: "header", command: "..."}`.
2. **FOLLOW-UP**: `context-mode_ctx_search(queries: ["q1", "q2", ...])` — all questions as array, ONE call (default relevance mode).
3. **PROCESSING**: `context-mode_ctx_execute(language, code)` | `context-mode_ctx_execute_file(path, language, code)` — sandbox, only stdout enters context.
4. **WEB**: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)` — raw HTML never enters context.
5. **INDEX**: `context-mode_ctx_index(content, source)` — store in FTS5 for later search.

## Parallel I/O batches

For multi-URL fetches or multi-API calls, **always** include `concurrency: N` (1-8):

- `context-mode_ctx_batch_execute(commands: [3+ network commands], concurrency: 5)` — gh, curl, dig, docker inspect, multi-region cloud queries
- `context-mode_ctx_fetch_and_index(requests: [{url, source}, ...], concurrency: 5)` — multi-URL batch fetch

**Use concurrency 4-8** for I/O-bound work (network calls, API queries). **Keep concurrency 1** for CPU-bound (npm test, build, lint) or commands sharing state (ports, lock files, same-repo writes).

GitHub API rate-limit: cap at 4 for `gh` calls.

## Output

Terse like caveman. Technical substance exact. Only fluff die.
Drop: articles, filler (just/really/basically), pleasantries, hedging. Fragments OK. Short synonyms. Code unchanged.
Pattern: [thing] [action] [reason]. [next step]. Auto-expand for: security warnings, irreversible actions, user confusion.
Write artifacts to FILES — never inline. Return: file path + 1-line description.
Descriptive source labels for `search(source: "label")`.

## Session Continuity

Skills, roles, and decisions persist for the entire session. Do not abandon them as the conversation grows.

## Memory

Session history is persistent and searchable. On resume, search BEFORE asking the user:

| Need | Command |
|------|---------|
| What did we decide? | `context-mode_ctx_search(queries: ["decision"], source: "decision", sort: "timeline")` |
| What constraints exist? | `context-mode_ctx_search(queries: ["constraint"], source: "constraint")` |

DO NOT ask "what were we working on?" — SEARCH FIRST.
If search returns 0 results, proceed as a fresh session.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call `stats` MCP tool, display full output verbatim |
| `ctx doctor` | Call `doctor` MCP tool, run returned shell command, display as checklist |
| `ctx upgrade` | Call `upgrade` MCP tool, run returned shell command, display as checklist |
| `ctx purge` | Call `purge` MCP tool with confirm: true. Warns before wiping knowledge base. |

After /clear or /compact: knowledge base and session stats preserved. Use `ctx purge` to start fresh.

<!-- END context-mode routing rules -->
