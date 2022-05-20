local commands = require("overseer.commands")
local config = require("overseer.config")
local constants = require("overseer.constants")
local Task = require("overseer.task")
local window = require("overseer.window")
local M = {}

-- TODO
-- * session-wrapper support
-- * { } to navigate task list
-- * Colorize task list
-- * Rerun on save optionally takes directory
-- * Autostart task on vim open in dir (needs some uniqueness checks)
--
-- WISHLIST
-- * re-run can interrupt (stop job)
-- * Definitely going to need some sort of logging system
-- * Notifier that notifies on fail, or transition from fail to success
-- * Live build a task from a template + components
-- * Load VSCode task definitions
-- * Store recent commands in history per-directory
--   * Can select & run task from recent history
-- * Add tests
-- * Maybe add a way to customize the task detail per-piece. e.g. {components = 0, result = 2}
-- * add debugging helpers for components
-- * component: parse output and populate quickfix
-- * task list: bulk actions
-- * ability to require task to be unique (disallow duplicates). Coordinate among all vim instances
-- * Quick jump to most recent task (started/notified)
-- * Rerun trigger handler feels different from the rest. Maybe separate it out.
-- * Lualine component
-- * Separation of registry and task list feels like it needs refactor

M.setup = function(opts)
  require("overseer.component").register_all()
  config.setup(opts)
  commands.create_commands()
end

M.new_task = function(opts)
  return Task.new(opts)
end

M.toggle = window.toggle
M.open = window.open
M.close = window.close

M.list_task_bundles = commands.list_task_bundles
M.load_task_bundles = commands.load_task_bundles
M.save_task_bundles = commands.save_task_bundles
M.delete_task_bundles = commands.delete_task_bundles
M.run_template = commands.run_template

M.TAG = constants.TAG
M.SLOT = constants.SLOT
M.STATUS = constants.STATUS

setmetatable(M, {
  __index = function(t, key)
    local ok, val = pcall(require, string.format("overseer.%s", key))
    if ok then
      rawset(t, key, val)
      return val
    else
      error(string.format("Error requiring overseer.%s: %s", key, val))
    end
  end,
})

return M
