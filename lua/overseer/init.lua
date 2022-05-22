local commands = require("overseer.commands")
local config = require("overseer.config")
local constants = require("overseer.constants")
local registry = require("overseer.registry")
local Task = require("overseer.task")
local window = require("overseer.window")
local M = {}

-- TODO
-- * Load VSCode task definitions
--   * just, make, tox, basically just need autocomplete for these
-- * Many more task templates, especially for tests
-- * Statusline integration for task status
-- * Add extension points to the task list actions
-- * Add tests
-- * keybinding help in float
-- * More schema validations (callback, non-empty list, number greater than,
-- * Pull as much logic out of the closures as possible
-- * Add nearest-test support detecting via treesitter
-- * Dynamic sizing for task editor
-- * component: parse output and populate quickfix/loclist (or diagnostics? signs? vtext?)
-- * Separation of registry and task list feels like it needs refactor
-- * Summary removes terminal escape chars
-- * Option to run task and immediately open terminal in (float/split/vsplit)
-- * { } to navigate task list
-- * Basic Readme
-- * Vim help docs
-- * Architecture doc (Template / Task / Component)
-- * Extension doc (how to make your own template/component)

M.setup = function(opts)
  require("overseer.component").register_builtin()
  config.setup(opts)
  commands.create_commands()
  vim.cmd([[
    hi default link OverseerPENDING Normal
    hi default link OverseerRUNNING Constant
    hi default link OverseerSUCCESS DiagnosticInfo
    hi default link OverseerCANCELED DiagnosticWarn
    hi default link OverseerFAILURE DiagnosticError
    hi default link OverseerTask Title
    hi default link OverseerTaskBorder FloatBorder
    hi default link OverseerOutput Normal
    hi default link OverseerSlot String
    hi default link OverseerComponent Constant
    hi default link OverseerField Keyword
  ]])
  local aug = vim.api.nvim_create_augroup("Overseer", {})
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

-- Re-export the constants
for k, v in pairs(constants) do
  M[k] = v
end

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
