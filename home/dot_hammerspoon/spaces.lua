-- ~/.hammerspoon/spaces.lua
-- Managed by chezmoi (source: home/dot_hammerspoon/spaces.lua). Do not edit directly.
--
-- Bind Ctrl+1 .. Ctrl+5 to jump directly to the Nth Space on the focused
-- screen, INCLUDING full-screen-app spaces.
--
-- Why this reaches full-screen spaces when the macOS built-ins do not:
--   * hs.spaces.spacesForScreen() returns every Space ID for a screen in
--     Mission Control order, including full screen / tiled application spaces
--     (hs.spaces.spaceType() reports those as "fullscreen").
--   * hs.spaces.gotoSpace() switches by driving the Mission Control thumbnail
--     button for that Space, so it can activate full-screen spaces. The native
--     "Switch to Desktop N" shortcuts (Ctrl+Number) skip them entirely.
--   Docs: https://www.hammerspoon.org/docs/hs.spaces.html
--
-- To extend, raise spaceCount (and add the matching Spaces in Mission Control).
-- Note: disable the built-in Mission Control "Switch to Desktop N" shortcuts in
-- System Settings -> Keyboard -> Keyboard Shortcuts -> Mission Control to avoid
-- a clash on Ctrl+Number.

local mods = { "ctrl" }
local spaceCount = 5

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

for i = 1, spaceCount do
  hs.hotkey.bind(mods, tostring(i), function()
    gotoSpaceIndex(i)
  end)
end
