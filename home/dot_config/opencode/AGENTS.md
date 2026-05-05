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
