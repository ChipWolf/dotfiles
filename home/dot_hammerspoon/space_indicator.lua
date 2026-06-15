-- ~/.hammerspoon/space_indicator.lua
-- Managed by chezmoi (source: home/dot_hammerspoon/space_indicator.lua). Do not edit directly.
--
-- Menu bar indicator showing which Space is currently active on the focused
-- screen: one dot per Space, the current one filled (●) and the rest hollow
-- (○), in Mission Control order (the same order Option+1..Option+5 use, see
-- spaces.lua). Full-screen-app spaces are counted too. The dropdown lists every
-- Space; click one to jump.
--
-- Space changes are detected with hs.spaces.watcher. The badge is recomputed
-- from hs.spaces.spacesForScreen + activeSpaceOnScreen rather than trusting the
-- watcher's (deprecated) space-number argument.

-- spaceIndicatorMenubar and spaceIndicatorWatcher are intentionally non-local
-- globals so the menu bar item and watcher are not garbage-collected; declare
-- them for luacheck (the hs runtime global is allowed via .mega-linter.yml).
-- luacheck: globals spaceIndicatorMenubar spaceIndicatorWatcher

-- Keep the menu bar item in a global so it is not garbage collected.
spaceIndicatorMenubar = hs.menubar.new()

local function focusedScreenSpaces()
	local screen = hs.screen.mainScreen()
	if not screen then
		return nil
	end
	local uuid = screen:getUUID()
	return uuid, hs.spaces.spacesForScreen(uuid), hs.spaces.activeSpaceOnScreen(uuid)
end

-- One dot per Space on the focused screen, the active one filled.
local function updateIndicator()
	if not spaceIndicatorMenubar then
		return
	end
	local _, spaces, active = focusedScreenSpaces()
	if not spaces or #spaces == 0 then
		spaceIndicatorMenubar:setTitle("•")
		return
	end
	local dots = {}
	for i, id in ipairs(spaces) do
		dots[i] = (id == active) and "●" or "○"
	end
	spaceIndicatorMenubar:setTitle(table.concat(dots))
end

if spaceIndicatorMenubar then
	-- Dropdown: every Space on the focused screen, current one checked, click to jump.
	spaceIndicatorMenubar:setMenu(function()
		local _, spaces, active = focusedScreenSpaces()
		local items = {}
		if spaces then
			for i, id in ipairs(spaces) do
				local suffix = (hs.spaces.spaceType(id) == "fullscreen") and " (full screen)" or ""
				items[#items + 1] = {
					title = "Space " .. i .. suffix,
					checked = (id == active),
					fn = function()
						hs.spaces.gotoSpace(id)
					end,
				}
			end
		else
			items[#items + 1] = { title = "Spaces unavailable", disabled = true }
		end
		return items
	end)
end

-- Recompute when the active Space changes: covers Ctrl+number, trackpad swipes,
-- and entering/leaving full-screen apps. The recompute is deferred briefly so it
-- reads once macOS has finished the transition and any most-recent-use
-- reordering, otherwise activeSpaceOnScreen can still report the old Space.
-- Keep the watcher in a global too.
spaceIndicatorWatcher = hs.spaces.watcher.new(function()
	hs.timer.doAfter(0.25, updateIndicator)
end)
spaceIndicatorWatcher:start()

updateIndicator()
