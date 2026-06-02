-- Headless installer for the LazyVim + Mason stack. Invoked by the chezmoi
-- bootstrap scripts to pre-install plugins and Mason-managed tools so the
-- first interactive launch is fast.
--
-- The naive `nvim --headless "+Lazy! sync" +qa` exits as soon as Lazy's own
-- queue drains, killing the editor while Mason is still installing tools
-- triggered by LazyVim's mason.nvim config and mason-nvim-dap. mason-lspconfig
-- explicitly skips ensure_installed in headless mode (see its features/
-- ensure_installed.lua), so LSP servers install on first interactive launch
-- regardless. This script waits for the work that *does* run headless.

local function log(msg)
  io.stderr:write(string.format('[headless-install] %s\n', msg))
end

log('starting Lazy sync (wait=true)')
require('lazy').sync({ wait = true, show = false })
log('Lazy sync done')

require('lazy').load({ plugins = { 'mason.nvim' } })
local mr = require('mason-registry')

local pending = 0
local seen_any = false

-- Mason emits `package:install:handle` when an install starts (carrying the
-- InstallHandle) and `package:install:success`/`:failed` on completion. There
-- is no `:start` event.
mr:on('package:install:handle', function(handle)
  pending = pending + 1
  seen_any = true
  local name = handle.package and handle.package.name or '?'
  log(string.format('install start: %s (pending=%d)', name, pending))
end)
mr:on('package:install:success', function(pkg)
  pending = pending - 1
  log(string.format('install success: %s (pending=%d)', pkg.name, pending))
end)
mr:on('package:install:failed', function(pkg)
  pending = pending - 1
  log(string.format('install failed: %s (pending=%d)', pkg.name, pending))
end)

log('loading mason-lspconfig and mason-nvim-dap (triggers ensure_installed)')
require('lazy').load({ plugins = { 'mason-lspconfig.nvim', 'mason-nvim-dap.nvim' } })

-- Wait up to 30s for the first install:handle event. ensure_installed runs
-- inside mason-registry.refresh() callbacks, which are async. If nothing
-- needs installing (everything already present and registry cache fresh),
-- no event fires and we proceed to exit.
log('waiting up to 30s for an install:handle event')
vim.wait(30000, function() return seen_any end, 200)

if not seen_any then
  log('no installs triggered; assuming nothing to do')
else
  log(string.format('draining mason install queue (%d pending, 10m cap)', pending))
  local ok = vim.wait(600000, function() return pending <= 0 end, 500)
  if not ok then
    log(string.format('timeout: %d installs still pending; exiting anyway', pending))
  else
    log('all mason installs complete')
  end
end

log('exiting')
vim.cmd('qa!')
