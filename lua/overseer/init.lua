local config = require("overseer.config")
local Task = require("overseer.task")
local template = require("overseer.template")
local window = require("overseer.window")
local M = {}

-- TODO
-- * View task output
--
-- WISHLIST
-- * Run a test (file/suite/line) and notify. Can inspect all output.
-- * Run a test (file/suite/line) every time you save a file (debounce).
-- * :make every time you save a file (debounce).
-- * Save task templates somehow
-- * Load VSCode task definitions
-- * Store recent commands in history per-directory
--   * Can select & run task from recent history
-- * Add tests
-- * add names & debugging helpers for capabilities

-- Extract pass/fail
-- Capture stdout/stderr
-- Processors for stdout/stderr
-- Callback when complete
-- Can be re-invoked once complete (doing so while running will queue the re-invoke)

M.setup = function(opts)
  config.setup(opts)
end

M.new_task = function(opts)
  return Task.new(opts)
end

M.toggle = window.toggle
M.open = window.open
M.close = window.close

M.start_from_template = function()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == "" then
    bufname = vim.fn.getcwd(0)
  end
  local ft = vim.api.nvim_buf_get_option(0, 'filetype')
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
    if not tmpl then
      return
    end
    tmpl:prompt({}, function(task)
      if not task then
        return
      end
      task:start()
    end)
  end)
end

setmetatable(M, {
  __index = function(_, key)
    local ok, val = pcall(require, string.format("overseer.%s", key))
    if ok then
      return val
    else
      error(val)
    end
  end,
})

return M
