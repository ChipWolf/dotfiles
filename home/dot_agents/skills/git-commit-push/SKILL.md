---
name: git-commit-push
description: Execute a safe commit-and-push workflow with parallel git context checks, cross-shell-safe commit message handling, and non-fast-forward remediation. Use when the user asks to commit and push changes.
---

## Goal

Capture the exact workflow for commit and push requests:

1. Run three repo-inspection commands in parallel.
2. Commit with a message that matches repo style.
3. Push.
4. If auth fails, run two diagnostics in parallel and retry push with a `mise x -- gh` credential helper.
5. If non-fast-forward, rebase onto `origin/main` and push again.

## Step 1, run three parallel checks

Run these in parallel:

- `git status --short --branch`
- `git diff --stat && git diff --staged --stat`
- `git log --oneline -n 10`

Use the outputs to:

- Confirm branch and changed files.
- Size and classify the change.
- Match commit message style.

## Step 2, stage and commit

Stage intended files and commit using a shell-safe multiline message strategy.

Template:

```sh
git add -A && git commit -m "$(cat <<'EOF'
<type>(<scope>): <short why-focused subject>

<1-2 sentence rationale>
EOF
)"
```

Windows and mixed-shell rule:

- If command execution is wrapped by PowerShell, do not use bash heredoc directly.
- Use a PowerShell here-string for multiline messages:

```powershell
$msg = @'
<type>(<scope>): <short why-focused subject>

<1-2 sentence rationale>
'@
git add -A
git commit -m $msg
```

- If you do use bash heredoc, invoke through `bash -lc` and keep all heredoc content inside that single bash command.

After commit, verify:

- `git status --short --branch`

## Step 3, attempt push

Try normal push first:

- `git push origin <branch>`

## Step 4, auth remediation with two parallel checks

If push fails with credential/auth errors, run these in parallel:

- `gh auth status`
- `git remote -v`

Then retry push with one-off helper (do not change global git config):

- `git -c credential.helper='!mise x -- gh auth git-credential' push origin <branch>`

## Step 5, non-fast-forward remediation

If push is rejected with `fetch first` or non-fast-forward:

1. Fetch using helper:
   - `git -c credential.helper='!mise x -- gh auth git-credential' fetch origin <branch>`
2. Inspect divergence:
   - `git status --short --branch`
   - `git log --oneline --decorate --graph --left-right --boundary origin/<branch>...<branch> -n 20`
3. Rebase local branch onto remote:
   - `git rebase origin/<branch>`
4. Push again with helper:
   - `git -c credential.helper='!mise x -- gh auth git-credential' push origin <branch>`
5. Verify clean sync:
   - `git status --short --branch`

## Guardrails

- Do not force-push unless explicitly requested.
- Do not modify global git config during remediation.
- Keep commit scope atomic, do not stage unrelated files.

## Self-improvement loop

After each use, run this loop before ending the task:

1. Check command output for friction patterns:
   - PowerShell parse errors involving heredoc (`<<EOF`, redirection operator errors).
   - Credential-helper failures (`gh: command not found`, helper not executable in shell).
   - Rebase/push branches not handled by the current instructions.
2. If a pattern appears, update this skill in chezmoi source:
   - `home/dot_agents/skills/git-commit-push/SKILL.md`
3. Keep updates concrete, command-level, and minimal.
4. Re-run the failing step once to validate the skill update.
