-- ~/.hammerspoon/init.lua
-- Managed by chezmoi (source: home/dot_hammerspoon/init.lua). Do not edit directly.
--
-- Hammerspoon configuration. Currently this only sets up direct macOS Space
-- switching; see spaces.lua for the keybindings and rationale.

-- Enable the `hs` command-line tool (talks to this instance over a message
-- port) so the config can be queried/scripted from a shell.
require("hs.ipc")

require("spaces")

-- Auto-reload the configuration whenever any .lua file under ~/.hammerspoon
-- changes. hs.pathwatcher uses FSEvents, which is path-based, so it survives
-- chezmoi's atomic writes (new inode on every apply) unlike inode-based
-- watchers. Keep the watcher in a global so it is not garbage collected.
local function reloadConfig(paths)
  for _, file in ipairs(paths) do
    if file:sub(-4) == ".lua" then
      hs.reload()
      return
    end
  end
end

configWatcher = hs.pathwatcher.new(hs.configdir, reloadConfig):start()

hs.alert.show("Hammerspoon config loaded")
