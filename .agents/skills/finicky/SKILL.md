---
name: finicky
description: Finicky browser-router config for this chezmoi repo (macOS). Covers the mandatory restart-after-apply procedure and why Finicky's auto-reload fails under chezmoi. Triggers — Finicky, browser router, auto-reload, inode, kqueue, fsnotify, restart required. Load before changing home/dot_config/finicky.js.tmpl.
---

# Finicky (macOS)

**Scope:** `home/dot_config/finicky.js.tmpl` (target `~/.config/finicky.js`).

After applying changes to the Finicky config (`~/.config/finicky.js`), reload it by:

1. `killall Finicky || true`
2. `open -a Finicky`
3. Close the foreground window manually (AppleScript window close is not available without assistive access)

Finicky's built-in auto-reload does NOT work when the config is managed by chezmoi. Chezmoi replaces the file with a new inode on every write; Finicky's fsnotify watcher (kqueue on macOS) tracks by inode and loses the watch when this happens. A restart is always required.
