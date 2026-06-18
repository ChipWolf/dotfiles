-- ~/.hammerspoon/spaces.lua
-- Managed by chezmoi (source: home/dot_hammerspoon/spaces.lua). Do not edit directly.
--
-- Jump directly to the Nth Space on the focused screen with Option+1 .. Option+5
-- (matching Komorebi's alt+number Workspace switches on Windows), INCLUDING
-- full-screen-app spaces. If a position does not exist yet an empty Space is
-- created and focused (see gotoSpaceIndex below).
--
-- Option+0 consolidates every window onto each screen's currently-focused Space,
-- un-full-screening any full-screen apps on the way (see consolidateWindows).
--
-- Why an event tap rather than hs.hotkey.bind:
--   On macOS, Option+1 .. Option+5 normally type the special characters
--   ¡ ™ £ ¢ ∞ (and Option+0 types º). The event tap returns true to swallow the
--   keystroke before the input system translates it, so the Space switches (or
--   consolidates) and no character is inserted. (An event tap is also the only
--   workable approach for Ctrl+number, which we do not use: macOS reserves
--   Ctrl+1 .. Ctrl+N as Carbon hotkeys for "Switch to Desktop" based on the
--   number of Mission Control user desktops even when the System Settings
--   checkboxes are off, so RegisterEventHotKey rejects them with -9878 and
--   hs.hotkey.bind cannot register them.)
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

-- Keycode for "0", which triggers consolidateWindows below.
local consolidateCode = hs.keycodes.map["0"]

-- Switch to the index-th (1-based) Space on the screen that currently has focus.
-- If that position does not exist yet, create a new empty Space and switch to
-- it rather than doing nothing.
local function gotoSpaceIndex(index)
	local screen = hs.screen.mainScreen()
	if not screen then
		return
	end
	local uuid = screen:getUUID()

	local spaces = hs.spaces.spacesForScreen(uuid)
	if not spaces then
		hs.alert.show("Spaces: could not read Spaces for the focused screen")
		return
	end

	local target = spaces[index]
	if target then
		hs.spaces.gotoSpace(target)
		return
	end

	-- Position index does not exist yet: add an empty Space and go to it.
	-- addSpaceToScreen does not return the new id, and a new desktop is not always
	-- appended last, so diff the Space list before and after to find it.
	local existed = {}
	for _, id in ipairs(spaces) do
		existed[id] = true
	end

	local ok, err = hs.spaces.addSpaceToScreen(uuid)
	if not ok then
		hs.alert.show("Could not add a Space: " .. tostring(err))
		return
	end

	local updated = hs.spaces.spacesForScreen(uuid)
	if updated then
		for _, id in ipairs(updated) do
			if not existed[id] then
				hs.spaces.gotoSpace(id)
				return
			end
		end
	end
end

-- Pull every standard window onto each screen's currently-focused Space,
-- un-full-screening any full-screen apps first so their dedicated full-screen
-- spaces collapse back into normal windows.
--
-- Per screen: hs.spaces.moveWindowToSpace cannot move a window across displays,
-- so each screen collects its own windows onto its own active Space.
--
-- hs.window.allWindows() reaches windows on Spaces other than the focused one
-- (the macOS Accessibility API only enumerates the current Space, but
-- Hammerspoon works around that), and hs.spaces.windowSpaces(win) reports which
-- Space(s) a window lives on so already-placed windows are left untouched.
local function consolidateWindows()
	-- 1) Un-full-screen everything; this dissolves the dedicated full-screen
	--    spaces back into user spaces.
	local hadFullscreen = false
	for _, win in ipairs(hs.window.allWindows()) do
		if win:isFullScreen() then
			win:setFullScreen(false)
			hadFullscreen = true
		end
	end

	local function gather()
		-- Resolve each screen's active Space after any full-screen spaces have
		-- collapsed, since positions can shift.
		local targetForScreen = {}
		for _, screen in ipairs(hs.screen.allScreens()) do
			targetForScreen[screen:getUUID()] = hs.spaces.activeSpaceOnScreen(screen:getUUID())
		end

		local moved = 0
		for _, win in ipairs(hs.window.allWindows()) do
			local screen = win:isStandard() and win:screen()
			local target = screen and targetForScreen[screen:getUUID()]
			if target then
				local onTarget = false
				for _, s in ipairs(hs.spaces.windowSpaces(win) or {}) do
					if s == target then
						onTarget = true
						break
					end
				end
				if not onTarget then
					hs.spaces.moveWindowToSpace(win:id(), target)
					moved = moved + 1
				end
			end
		end
		hs.alert.show(string.format("Consolidated %d window(s)", moved))
	end

	-- Give macOS a moment to tear down full-screen spaces before moving windows.
	if hadFullscreen then
		hs.timer.doAfter(1.0, gather)
	else
		gather()
	end
end

-- Keep the tap in a global so it is not garbage collected.
-- luacheck: globals spaceSwitchTap
spaceSwitchTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	-- Option must be the only modifier, so Option+Shift+1 and friends pass through.
	if not event:getFlags():containExactly({ "alt" }) then
		return false
	end

	local keyCode = event:getKeyCode()

	-- Option+0 consolidates all windows onto each screen's focused Space.
	if keyCode == consolidateCode then
		hs.timer.doAfter(0, consolidateWindows)
		return true -- swallow the keystroke
	end

	local index = codeToIndex[keyCode]
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
