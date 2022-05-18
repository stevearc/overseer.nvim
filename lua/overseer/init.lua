local config = require("overseer.config")
local Task = require("overseer.task")
local template = require("overseer.template")
local window = require("overseer.window")
local M = {}

-- TODO
-- * Capabilities should have name + category
-- * Capabilities can put output in the render list (i.e. "queued rerun", "rerun on fail")
-- * Mark a task to re-run on change
--
-- WISHLIST
-- * Run a test (file/suite/line) and notify.
-- * Run a test (file/suite/line) every time you save a file (debounce).
-- * :make every time you save a file (debounce).
-- * Save task templates somehow
-- * Load VSCode task definitions
-- * Store recent commands in history per-directory
--   * Can select & run task from recent history
-- * Add tests
-- * add names & debugging helpers for capabilities
-- * Require task to be unique (disallow duplicates). Coordinate among all vim instances
-- * Jump to most recent task (started/notified)

M.setup = function(opts)
  config.setup(opts)
end

M.new_task = function(opts)
  return Task.new(opts)
end

M.toggle = window.toggle
M.open = window.open
M.close = window.close

M.load_from_template = function(name, params, silent)
  vim.validate({
    name = {name, 's'},
    params = {params, 't', true},
    silent = {silent, 'b', true},
  })
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == "" then
    bufname = vim.fn.getcwd(0)
  end
  local ft = vim.api.nvim_buf_get_option(0, 'filetype')
  local template = template.get_by_name(name, bufname, ft)
  if not template then
    if silent then
      return
    else
      error(string.format("Could not find template '%s'", name))
    end
  end
  template:build(params or {})
end

M.start_from_template = function(name, params)
  vim.validate({
    name = {name, 's', true},
    params = {params, 't', true},
  })
  params = params or {}
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == "" then
    bufname = vim.fn.getcwd(0)
  end
  local ft = vim.api.nvim_buf_get_option(0, 'filetype')

  if name then
    local template = template.get_by_name(name, bufname, ft)
    if not template then
      error(string.format("Could not find template '%s'", name))
    end
    template:prompt(params, function(task)
      if task then
        task:start()
      end
    end)
  else
    local templates = template.list(bufname, ft)
    vim.ui.select(templates, {
      prompt = "Task template:",
      kind = 'overseer_template',
      format_item = function(tmpl)
        if tmpl.description then
          return string.format("%s (%s)", tmpl.name, tmpl.description)
        else
          return tmpl.name
        end
      end,
    }, function(tmpl)
      if tmpl then
        tmpl:prompt(params, function(task)
          if task then
            task:start()
          end
        end)
      end
    end)
  end
end

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
