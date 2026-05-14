# Global agent rules

These rules apply to every coding session, across every project.

---

## Always active

These constraints are unconditional. Apply them without being asked.

- **No em dashes.** Use commas, colons, or restructure the sentence. Never generate `—`, `---`, or `&mdash;`.
- **Never guess schemas or APIs.** Read the authoritative source first (Go structs, official docs, or the project's own examples). Blog posts and AI-generated examples are not acceptable. If docs don't render, clone the repo and read the struct tags directly.
- **Clone repos to read source.** Never curl GitHub API endpoints or fetch raw URLs. `git clone` first, then read.
- **All Python through mise.** Never invoke `python`, `pip`, `uv`, or `uvx` directly. Use `mise x -- <command>` for all Python toolchain work.
- **Never accept a limitation without investigating.** Keep working until the problem is actually solved. Suggesting workarounds as a final answer is not acceptable.
- **Don't say "Docker containers."** Docker is a brand name, not a container type. Write "containers" or "OCI images" in prose. Action references like `docker/login-action` are fine as-is.

---

## Session close: mandatory

After every non-trivial task, run a retrospective before closing out.

---

## Memory

Global memory is `~/.agents/AGENTS.md` (source: `~/.local/share/chezmoi/home/dot_agents/AGENTS.md`).
Local memory is the `AGENTS.md` in the current project root (or nearest ancestor).

Never edit `~/.agents/AGENTS.md` directly; it is chezmoi-managed.

For rules specific to the chezmoi dotfiles repo itself, the target is `~/.local/share/chezmoi/AGENTS.md`.

When updating any memory file: review nearby rules for contradictions, duplication, and scope conflicts; reconcile in the same edit. Keep cross-cutting rules in global memory; keep project-specific rules in local memory.

---

## Git and commits

- Before committing, run `git diff --staged` and confirm the change is atomic and in-scope. Do not commit unrelated modifications.
- Commit message format: `type(scope): description`. Types: `feat`, `fix`, `chore`. Check `git log --oneline` to match repo style.
- After any branch switch (including `gh pr checkout`), immediately verify with `git branch --show-current`. `gh pr checkout` can silently leave you on the wrong branch when the local tracking branch has diverged; if it fails or the branch is wrong, use `git checkout <branch-name>` directly.
- A stale `.git/index.lock` blocks all git operations. Remove it with `rm -f .git/index.lock` before retrying the blocked command.
- **Worktree context.** When the cwd is inside a Claude Code worktree (e.g. `.claude/worktrees/<id>`), git and gh commands operate on the worktree branch, not the main repo. The main repo's working tree may be locked by another agent; do not attempt `git checkout` or `gh pr checkout` against it. Instead, materialize a PR branch into a new isolated worktree: `git -C /path/to/main-repo fetch origin <branch> && git -C /path/to/main-repo worktree add <path> origin/<branch>`. Then work from that worktree path using `git -C <worktree-path>` for every subsequent git command. Never rely on `cd` + bare `git` across separate Bash calls: shell state resets between calls, so the cwd silently reverts and commands run against the wrong worktree. Always confirm the active branch with `git -C <path> branch --show-current` before reading or editing files.
- **Cloning for tag comparison.** `--depth=1 --no-single-branch` does not fetch tags. When you need to compare specific tags, either clone without `--depth`, or run `git fetch --tags` after the shallow clone.
- **Inspecting a PR's diff.** Always diff the remote PR branch against `origin/main` (e.g. `git diff origin/main...origin/<pr-branch>`), not local HEAD. Local HEAD may be on an unrelated branch, so a diff against it is meaningless and returns empty output without any error.

---

## Shell discipline

- Prefer the smallest atomic command that completes the immediate next step. Do not chain concerns across policy boundaries.
- Keep source edits, `chezmoi apply`, and git operations as separate commands unless a later step strictly depends on the previous one within the same concern.
- Destructive or policy-sensitive actions should be isolated so intent is easy to inspect.
- Do not check whether a directory exists before using it. Attempt the operation; create the directory if it fails.
- On Windows, when admin rights are required, launch elevated commands with `Start-Process -Verb RunAs` instead of failing back to manual instructions.
- On Windows, use the Bash tool (not PowerShell) for POSIX-style commands like `grep`, `find`, `head`, `tail`, and path operations that use forward slashes. Use PowerShell only when you need Windows-native cmdlets, `$env:` variables, or paths with backslashes that POSIX tools cannot handle.

---

## Toolchain

- When a CLI can be managed by `mise`, run it through `mise x -- <command>`. Do not invoke managed tools directly.
- When `chezmoi apply` triggers a brew bundle run (via an onchange script), treat it as fire-and-forget once the apply succeeds.
- If `chezmoi apply` fails because an unrelated template needs a secret (e.g. Bitwarden locked), apply only the file you need with `chezmoi apply <target-path>` to bypass the failing template.
