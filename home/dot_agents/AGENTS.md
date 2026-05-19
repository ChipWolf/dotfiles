# Global agent rules

These rules apply to every coding session, across every project.

**Precedence:** the **closest `AGENTS.md`** to the files you're changing wins. This file holds cross-tool defaults; project and directory `AGENTS.md` files override on conflict. See the [Memory](#memory) section for where each file lives.

---

## Always active

These constraints are unconditional. Apply them without being asked.

- **No em dashes.** Use commas, colons, or restructure the sentence. Never generate inline `—` or `&mdash;` as punctuation. (Markdown horizontal rules: `---` alone on a line is fine.)
- **Never guess schemas or APIs.** Read the authoritative source first: Go structs, official docs, or the project's own examples. Blog posts and AI-generated examples are not acceptable.
- **Verify a dependency supports the target platform before designing around it.** Before locking in a spec that depends on a third-party tool on a specific OS, confirm artifacts and source actually support that OS: run `gh release view --json assets` to see what's published, check the upstream CI matrix for the OSes it builds, and grep the source for OS-specific imports or build tags. Project names and descriptions don't imply cross-platform binaries; many "general" tools are Linux-only at the artifact level even when the README sounds portable.
- **Diagnose from logs, not theory.** When investigating a failure (CI, runtime, hang, regression), the last lines of output before the failure are ground truth, not a guess based on which script's name matches your current hypothesis or which prior bug looked similar. If the visible log doesn't pin the cause, add a diagnostic and re-run rather than speculate further. When reporting findings, mark claims as observed ("log line N says X") versus suspected ("I think Y because…") and never let suspicion harden into assertion without evidence.
- **Clone, don't curl.** When reading another repository's source, `git clone` first and read locally. Never `curl` GitHub API endpoints or `curl` raw file URLs to read source, even when docs don't render. (Using `WebFetch` for public documentation pages is fine.)
- **All Python through mise.** Never invoke `python`, `pip`, `uv`, or `uvx` directly. Use `mise x -- <command>` for all Python toolchain work.
- **Never accept a limitation without investigating.** Keep working until the problem is actually solved. Suggesting workarounds as a final answer is not acceptable.
- **Deliver the answer, not instructions to derive it.** When the user asks you to find, fetch, or compute a specific value, produce the value. Do not respond with a snippet for them to run, a formula to apply, or "tell me which one and I'll convert it" when you have the tools to do the lookup yourself. The user delegated the work; punting it back defeats the purpose.
- **Don't say "Docker containers."** Docker is a brand name, not a container type. Write "containers" or "OCI images" in prose. Action references like `docker/login-action` are fine as-is.
- **Never commit secrets.** No API keys, tokens, `.env` files, credentials, or private keys in any repo. If staged accidentally, unstage and remove from history before pushing. If already pushed, rotate the secret immediately; force-push history rewrite only with explicit user confirmation.
- **Never log PII.** No email, phone, name, address, or payment data in logs, traces, or monitoring payloads.
- **Run a retrospective before closing out.** After every non-trivial task, invoke the `retrospective` skill to capture lessons for global memory.

---

## Memory

| Scope | Deployed path | Edit (source of truth) |
|---|---|---|
| Global cross-tool rules | `~/.agents/AGENTS.md` | `~/.local/share/chezmoi/home/dot_agents/AGENTS.md` |
| Global cross-tool skills | `~/.agents/skills/` | `~/.local/share/chezmoi/home/dot_agents/skills/` |
| Project rules | `./AGENTS.md` (project root or nearest ancestor) | same path |
| Chezmoi repo rules | `~/.local/share/chezmoi/AGENTS.md` | same path |

Always edit the source, not the deployed file. When updating any memory file: review nearby rules for contradictions, duplication, and scope conflicts; reconcile in the same edit. Keep cross-cutting rules in global memory; keep project-specific rules in local memory.

---

## Git and commits

- **Check for prior work before starting a fix.** When the task is to fix a specific CI failure, bug, or pre-described change, scan `gh pr list --state all --search <keywords>` and `git worktree list` before reading code or planning. Previous sessions or parallel agents may already have a branch, open PR, or merged PR matching the scope; duplicating that work wastes effort and risks conflicting changes.
- Before committing, run `git diff --staged` and confirm the change is atomic and in-scope. Do not commit unrelated modifications.
- Commit message format: `type(scope): description`. Types: `feat`, `fix`, `chore`. Check `git log --oneline` to match repo style.
- After any branch switch (including `gh pr checkout`), verify with `git branch --show-current`. If `gh pr checkout` fails or lands on the wrong branch, use `git checkout <branch>` directly.
- A stale `.git/index.lock` blocks all git operations. Remove it with `rm -f .git/index.lock` before retrying the blocked command.
- **Worktree context.**
    - When the cwd is inside a Claude Code worktree (e.g. `.claude/worktrees/<id>`), git and gh commands act on the worktree branch. The main repo's working tree may be locked by another agent; do not `git checkout` or `gh pr checkout` against it.
    - To pull a PR branch, materialize it into a new worktree: `git -C /path/to/main-repo fetch origin <branch> && git -C /path/to/main-repo worktree add <path> origin/<branch>`.
    - Use `git -C <path>` for all subsequent commands. Confirm the active branch with `git -C <path> branch --show-current` before reading or editing files.
- **Cloning for tag comparison.** `--depth=1 --no-single-branch` does not fetch tags. When you need to compare specific tags, either clone without `--depth`, or run `git fetch --tags` after the shallow clone.
- **Inspecting a PR's diff.** Always diff the remote PR branch against `origin/main` (e.g. `git diff origin/main...origin/<pr-branch>`), not local HEAD. Local HEAD may be on an unrelated branch, so a diff against it is meaningless and returns empty output without any error.
- **Before opening a PR: clean up history.** Squash messy work-in-progress or AI-attributed commits into a clean, atomic commit sequence on the branch. The branch is yours until `gh pr create` succeeds.
- **Once a PR is open: never amend or force-push.** Use follow-up commits so reviewers see exactly what changed between their review and your response. The branch now belongs to the reviewer; rewriting it erases the diff they expect to see. Preserve every change as a separate commit.

---

## Shell discipline

- Prefer the smallest atomic command that completes the immediate next step. Do not chain concerns across policy boundaries.
- Destructive or policy-sensitive actions should be isolated so intent is easy to inspect.
- Do not check whether a directory exists before using it. Attempt the operation; create the directory if it fails.
- On Windows, when admin rights are required, launch elevated commands with `Start-Process -Verb RunAs` instead of failing back to manual instructions.
- On Windows, use the Bash tool (not PowerShell) for POSIX-style commands like `grep`, `find`, `head`, `tail`, and path operations that use forward slashes. Use PowerShell only when you need Windows-native cmdlets, `$env:` variables, or paths with backslashes that POSIX tools cannot handle.
- On Windows, POSIX-style paths like `/tmp/...` resolve only inside the Bash tool. Native filesystem tools (read/edit/write/grep/glob in any agent harness) use Windows file APIs and need Windows-style paths (`C:\...` or `C:/...`). When a Bash command reports a canonical path (e.g. `Cloning into 'C:/Users/.../Temp/repo'`), use that path for subsequent tool calls; do not reuse the `/tmp/` shortcut.

---

## Toolchain

- When a CLI can be managed by `mise`, run it through `mise x -- <command>`. Do not invoke managed tools directly.
- When entering a new worktree that has a `mise.toml` or `.mise.toml`, run `mise trust <worktree-path>/{mise,.mise}.toml` (or the specific file present) before any `mise x --` call. Otherwise every mise invocation fails with `Config files in <path> are not trusted`.
