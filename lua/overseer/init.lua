local commands = require("overseer.commands")
local config = require("overseer.config")
local constants = require("overseer.constants")
local task_bundle = require("overseer.task_bundle")
local task_list = require("overseer.task_list")
local Task = require("overseer.task")
local util = require("overseer.util")
local window = require("overseer.window")
local M = {}

-- TODO
-- * make a suite of built-in parsers
-- * Components can set serializable = false (either fail serialization or silently exclude component)
-- * Many more task templates, especially for tests
-- * Right now we only support a single stacktrace. Might be nice to support potentially one per test?
-- * Add tests
-- * More comments
-- * More schema validations (callback, non-empty list, number greater than, enum, list[enum])
--   * list params allow escaping / quotes / specifying delimiter
-- * Pull as much logic out of the closures as possible
-- * Sandbox calls and log errors
--   * metagen
--   * task dispatch
-- * Add nearest-test support detecting via treesitter
-- * Dynamic window sizing for task editor
-- * _maybe_ support other run strategies besides terminal
-- * Basic Readme
-- * Vim help docs
-- * Architecture doc (Template / Task / Component)
-- * Extension doc (how to make your own template/component)
-- * Extension names could collide. Namespace internal & external extensions separately
-- * Figure out some clever way to lazy-load everything

M.setup = function(opts)
  config.setup(opts)
  commands.create_commands()
  -- TODO probably want to move this
  require("overseer.testing").create_commands()
  require("overseer.parsers").register_builtin()
  local success_color = util.find_success_color()
  vim.cmd(string.format(
    [[
    hi default link OverseerPENDING Normal
    hi default link OverseerRUNNING Constant
    hi default link OverseerSUCCESS %s
    hi default link OverseerCANCELED DiagnosticWarn
    hi default link OverseerFAILURE DiagnosticError
    hi default link OverseerDISPOSED Comment
    hi default link OverseerTask Title
    hi default link OverseerTaskBorder FloatBorder
    hi default link OverseerOutput Normal
    hi default link OverseerComponent Constant
    hi default link OverseerField Keyword
    hi default link OverseerTestNONE Normal
    hi default link OverseerTestRUNNING Constant
    hi default link OverseerTestSUCCESS %s
    hi default link OverseerTestFAILURE DiagnosticError
    hi default link OverseerTestSKIPPED DiagnosticWarn
    hi default link OverseerTestDuration Comment
  ]],
    success_color,
    success_color
  ))
  local aug = vim.api.nvim_create_augroup("Overseer", {})
  if config.auto_detect_success_color then
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "*",
      group = aug,
      desc = "Set Overseer default success color",
      callback = function()
        success_color = util.find_success_color()
        print(string.format("LINK %s", success_color))
        vim.cmd(string.format("hi link OverseerSUCCESS %s", success_color))
        vim.cmd(string.format("hi link OverseerTestSUCCESS %s", success_color))
      end,
    })
  end
  vim.api.nvim_create_autocmd("User", {
    pattern = "SessionSavePre",
    desc = "Save task state when vim-session saves",
    group = aug,
    callback = function()
      local cmds = vim.g.session_save_commands
      local tasks = task_list.serialize_tasks()
      if vim.tbl_isempty(tasks) then
        return
      end
      table.insert(cmds, '" overseer.nvim')
      local data = string.gsub(vim.json.encode(tasks), "\\/", "/")
      data = string.gsub(data, "'", "\\'")
      table.insert(
        cmds,
        -- For some reason, vim.json.encode encodes / as \/.
        string.format("lua require('overseer')._start_tasks('%s')", data)
      )
      vim.g.session_save_commands = cmds
    end,
  })
end

M.wrap_test = function(name, opts)
  return setmetatable(opts, {
    __index = function(_, key)
      if key == "super" then
        return require(string.format("overseer.testing.%s", name))
      else
        return require(string.format("overseer.testing.%s", name))[key]
      end
    end,
  })
end

M.new_task = Task.new

M.toggle = window.toggle
M.open = window.open
M.close = window.close

M.list_task_bundles = task_bundle.list_task_bundles
M.load_task_bundle = task_bundle.load_task_bundle
M.save_task_bundle = task_bundle.save_task_bundle
M.delete_task_bundle = task_bundle.delete_task_bundle

M.run_template = commands.run_template

-- Re-export the constants
for k, v in pairs(constants) do
  M[k] = v
end

-- Used for vim-session integration.
local timer_active = false
M._start_tasks = function(str)
  -- HACK for some reason vim-session fires SessionSavePre multiple times, which
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
