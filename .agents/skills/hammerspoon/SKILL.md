---
name: hammerspoon
description: Hammerspoon macOS Space-switching config for this chezmoi repo. Covers eventtap-vs-hotkey.bind, full-screen spaces, Accessibility, and debugging via the hs CLI. Triggers: Hammerspoon, macOS Spaces, Space switching, eventtap, hotkey.bind, Ctrl+1, Mission Control, Carbon hotkey reservation, hs.spaces, hs.ipc, Accessibility. Load before changing home/dot_hammerspoon/*.
---

# Hammerspoon (macOS Spaces)

**Scope:** `home/dot_hammerspoon/init.lua`, `home/dot_hammerspoon/spaces.lua` (→ `~/.hammerspoon/`).

Hammerspoon provides direct macOS Space switching: `⌃1`–`⌃5` jump to the Nth Space on the focused screen, including full-screen-app spaces. Cask in `home/.chezmoidata/brew/00-base.yaml` (macOS-gated); config at `home/dot_hammerspoon/{init.lua,spaces.lua}` (→ `~/.hammerspoon/`), gated to darwin in `home/.chezmoiignore`. Gotchas that have bitten us:

- **Use `hs.eventtap`, not `hs.hotkey.bind`, for `⌃`+number Space switches.** macOS reserves `⌃1`..`⌃N` as Carbon hotkeys for "Switch to Desktop" based on the number of Mission Control *user* desktops, even when the System Settings "Switch to Desktop" checkboxes are off. `RegisterEventHotKey` then rejects those combos: `hs.hotkey:enable()` returns nil and the console logs `-9878 ... already registered`, so `hs.hotkey.bind` silently fails for the low-numbered keys (for example `⌃1`/`⌃2` when two desktops exist) while higher ones bind fine. An event tap reads the keystroke from the event stream before hotkey dispatch and is not subject to the reservation. Diagnose with `hs -c 'return #hs.hotkey.getHotkeys()'` (binds missing) plus the Hammerspoon console.
- **`hs.spaces` reaches full-screen spaces.** `hs.spaces.spacesForScreen(uuid)` lists every Space (user and full screen/tiled, per `hs.spaces.spaceType`) in Mission Control order, and `hs.spaces.gotoSpace(id)` activates one by driving its Mission Control thumbnail, so it can land on full-screen spaces (the native `⌃`+number shortcuts cannot). Map "Space N" by indexing that list by position.
- **Auto-reload works.** `hs.pathwatcher` uses FSEvents (path-based), so it survives chezmoi's atomic-rename writes (new inode each apply). By contrast, Finicky's `fsnotify`/kqueue watcher is inode-based and loses the watch on every chezmoi write, so Finicky needs a manual restart (see the `finicky` skill).
- **`hs.ipc` is enabled** in `init.lua`, so the running config is queryable from the `hs` CLI (`hs -c '...'`), the main way to debug Spaces and hotkeys.
- **Requires Accessibility** permission (System Settings → Privacy & Security → Accessibility); `gotoSpace` drives Mission Control through the Accessibility API. One-time manual grant, cannot be automated by chezmoi.
