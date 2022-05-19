local config = require("overseer.config")
local Task = require("overseer.task")
local template = require("overseer.template")
local window = require("overseer.window")
local M = {}

-- TODO
-- * Figure out how templates work with capabilities
--   * For example, a test tmpl may need to override the exit_code handler. How to specify that it *overrides* one handler but *merges* with the others (e.g. notifier)
--   * What if we have dispose_delay on a test task, but want to edit it to rerun on save AND remove dispose_delay? How can we add an action that does this in a generic way? (in case a custom capability is used instead of dispose_delay)
-- * Capabilities can put output in the render list (i.e. "queued rerun", "rerun on fail")
-- * Save current state of tasks (incl modifications)
-- * get default capabilities by category from config
--
-- WISHLIST
-- * probably rename capability -> component
-- * re-run can interrupt (stop job)
-- * Live build a task from a template + capabilities
-- * Can create capability alias for groups of capabilities
-- * Save bundle of tasks for restoration
-- * Load VSCode task definitions
-- * Store recent commands in history per-directory
--   * Can select & run task from recent history
-- * Add tests
-- * add debugging helpers for capabilities
-- * parse output and populate quickfix
-- * Require task to be unique (disallow duplicates). Coordinate among all vim instances
-- * Jump to most recent task (started/notified)
-- * Rerun trigger handler feels different from the rest. Maybe separate it out.
-- * Do we actually need the capability categories?

M.setup = function(opts)
  require("overseer.capability").register_all()
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
    name = { name, "s" },
    params = { params, "t", true },
    silent = { silent, "b", true },
  })
  params = params or {}
  params.bufname = vim.api.nvim_buf_get_name(0)
  params.dirname = vim.fn.getcwd(0)
  local dir = params.bufname
  if dir == "" then
    dir = params.dirname
  end
  local ft = vim.api.nvim_buf_get_option(0, "filetype")
  local tmpl = template.get_by_name(name, dir, ft)
  if not tmpl then
    if silent then
      return
    else
      error(string.format("Could not find template '%s'", name))
    end
  end
  return tmpl:build(params)
end

M.start_from_template = function(name, params)
  vim.validate({
    name = { name, "s", true },
    params = { params, "t", true },
  })
  if name then
    local task = M.load_from_template(name, params)
    task:start()
    return
  end
  params = params or {}
  params.bufname = vim.api.nvim_buf_get_name(0)
  params.dirname = vim.fn.getcwd(0)
  local dir = params.bufname
  if dir == "" then
    dir = params.dirname
  end
  local ft = vim.api.nvim_buf_get_option(0, "filetype")

  local templates = template.list(dir, ft)
  vim.ui.select(templates, {
    prompt = "Task template:",
    kind = "overseer_template",
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
