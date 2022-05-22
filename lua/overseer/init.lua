local commands = require("overseer.commands")
local config = require("overseer.config")
local constants = require("overseer.constants")
local registry = require("overseer.registry")
local Task = require("overseer.task")
local window = require("overseer.window")
local M = {}

-- TODO
--
-- BETA
-- * { } to navigate task list
-- * Add tests
-- * keybinding help in float
-- * when jumping around terminals, somehow the buffers become listed
-- * More schema validations (callback, non-empty list, number greater than,
-- * Register template with callback conditional (e.g. make only when Makefile exists)
-- * Summary stores N most recent lines
-- * Pull as much logic out of the closures as possible
-- * Better highlight groups (link instead of directly using Keyword/Comment)
-- * Many more task templates, especially for tests
-- * Load VSCode task definitions
-- * Add extension points to the task list actions
-- * Basic Readme
-- * Vim help docs
-- * Dynamic sizing for task editor
-- * Architecture doc (Template / Task / Component)
-- * Extension doc (how to make your own template/component)
-- * should we allow duplicate template names? how to handle double-register gracefully?
-- * component: parse output and populate quickfix
-- * Separation of registry and task list feels like it needs refactor
-- * Form and task editor logic is really messy. IDK about this field shit.
-----------------------------------------
-- FUTURE
-- * Timestamp status changes
-- etc)
-- * What about task chaining? Do we care?
-- * Rethink the detail levels
-- * Definitely going to need some sort of logging system
-- * Store recent commands in history per-directory
--   * Can select & run task from recent history
-- * add debugging helpers for components
-- * task list: bulk actions
-- * params can be file/dir type and will autocomplete
-- * more powerful param schema (e.g. nested types)
-- * list params allow escaping / quotes / specifying delimiter
-- * ability to require task to be unique (disallow duplicates). Coordinate among all vim instances
-- * Autostart task on vim open in dir (needs some uniqueness checks)
-- * Lualine component

M.setup = function(opts)
  require("overseer.component").register_all()
  config.setup(opts)
  commands.create_commands()
  local aug = vim.api.nvim_create_augroup("Overseer", {})
  vim.cmd([[
    hi default link OverseerRUNNING Constant
    hi default link OverseerSUCCESS DiagnosticInfo
    hi default link OverseerCANCELED DiagnosticWarn
    hi default link OverseerFAILURE DiagnosticError
    hi default link OverseerTask Title
    hi default link OverseerTaskBorder FloatBorder
    hi default link OverseerOutput Comment
    hi default link OverseerSlot String
    hi default link OverseerComponent Constant
    hi default link OverseerField Keyword
  ]])
  vim.api.nvim_create_autocmd("User", {
    pattern = "SessionSavePre",
    desc = "Save task state when vim-session saves",
    group = aug,
    callback = function()
      local cmds = vim.g.session_save_commands
      local tasks = registry.serialize_tasks()
      if vim.tbl_isempty(tasks) then
        return
      end
      table.insert(cmds, '" overseer.nvim')
      table.insert(
        cmds,
        string.format("lua require('overseer')._start_tasks([[ %s ]])", vim.json.encode(tasks))
      )
      vim.g.session_save_commands = cmds
    end,
  })
end

M.new_task = Task.new

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

-- Used for vim-session integration.
local timer_active = false
M._start_tasks = function(str)
  -- HACK for some reason vim-session first SessionSavePre multiple times, which
  -- can lead to multiple 'load' lines in the same session file. We need to make
  -- sure we only take the first one.
  if timer_active then
    return
  end
  timer_active = true
  vim.defer_fn(function()
    local data = vim.json.decode(str)
    for _, params in ipairs(data) do
      local task = Task.new(params)
      task:start()
    end
    timer_active = false
  end, 100)
end

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
