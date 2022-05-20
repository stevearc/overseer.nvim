local commands = require("overseer.commands")
local config = require("overseer.config")
local Task = require("overseer.task")
local window = require("overseer.window")
local M = {}

-- TODO
-- * { } to navigate task list
-- * Colorize task list
-- * Maybe need category/tags for templates? (e.g. "Run test")
-- * Rerun on save optionally takes directory
-- * Autostart task on vim open in dir (needs some uniqueness checks)
--
-- WISHLIST
-- * re-run can interrupt (stop job)
-- * Definitely going to need some sort of logging system
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
M.create_from_template = commands.create_from_template
M.start_from_template = commands.start_from_template

setmetatable(M, {
  __index = function(_, key)
    local ok, val = pcall(require, string.format("overseer.%s", key))
    if ok then
      return val
    else
      error(string.format("Error requiring overseer.%s: %s", key, val))
    end
  end,
})

return M
