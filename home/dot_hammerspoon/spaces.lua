-- ~/.hammerspoon/spaces.lua
-- Managed by chezmoi (source: home/dot_hammerspoon/spaces.lua). Do not edit directly.
--
-- Jump directly to the Nth Space on the focused screen with Ctrl+1 .. Ctrl+5,
-- INCLUDING full-screen-app spaces.
--
-- Why an event tap instead of hs.hotkey.bind:
--   macOS reserves Ctrl+1 .. Ctrl+N as Carbon hotkeys for "Switch to Desktop"
--   whenever N Mission Control *user* desktops exist, even when the System
--   Settings shortcut checkboxes are turned off. RegisterEventHotKey then
--   rejects those combos (error -9878 "already registered"), so hs.hotkey.bind
--   silently fails for the low-numbered keys (e.g. Ctrl+1/Ctrl+2 with two
--   desktops) while the higher ones work. An hs.eventtap sees the keystroke in
--   the event stream before hotkey dispatch, so it handles every Ctrl+number
--   uniformly and can swallow it.
--
-- Why this reaches full-screen spaces:
--   hs.spaces.spacesForScreen() lists every Space (user and full screen / tiled,
--   per hs.spaces.spaceType) in Mission Control order, and hs.spaces.gotoSpace()
--   activates a Space by driving its Mission Control thumbnail button, which can
--   land on full-screen spaces. The native shortcuts cannot.
--   Docs: https://www.hammerspoon.org/docs/hs.spaces.html
--
-- To extend, raise spaceCount (and add the matching Spaces in Mission Control).

local spaceCount = 5

-- Map the physical keycodes for "1".."spaceCount" to their 1-based index.
local codeToIndex = {}
for i = 1, spaceCount do
  local code = hs.keycodes.map[tostring(i)]
  if code then
    codeToIndex[code] = i
  end
end

-- Switch to the index-th (1-based) Space on the screen that currently has focus.
local function gotoSpaceIndex(index)
  local screen = hs.screen.mainScreen()
  if not screen then
    return
  end

  local spaces = hs.spaces.spacesForScreen(screen:getUUID())
  if not spaces then
    hs.alert.show("Spaces: could not read Spaces for the focused screen")
    return
  end

  local target = spaces[index]
  if not target then
    hs.alert.show(string.format("No Space %d on this screen", index))
    return
  end

  hs.spaces.gotoSpace(target)
end

-- Keep the tap in a global so it is not garbage collected.
spaceSwitchTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  -- Control must be the only modifier, so Ctrl+Shift+1 and friends pass through.
  if not event:getFlags():containExactly({ "ctrl" }) then
    return false
  end

  local index = codeToIndex[event:getKeyCode()]
  if not index then
    return false
  end

  -- Defer the switch so the Mission Control animation does not block the tap.
  hs.timer.doAfter(0, function()
    gotoSpaceIndex(index)
  end)
  return true -- swallow the keystroke
end)

spaceSwitchTap:start()
