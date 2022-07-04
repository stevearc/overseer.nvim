local action_util = require("overseer.action_util")
local constants = require("overseer.constants")
local log = require("overseer.log")
local sidebar = require("overseer.task_list.sidebar")
local task_bundle = require("overseer.task_bundle")
local task_list = require("overseer.task_list")
local template = require("overseer.template")
local Task = require("overseer.task")
local task_editor = require("overseer.task_editor")
local window = require("overseer.window")

local M = {}

M._open = function(params)
  window.open({ enter = not params.bang })
end

M._close = function(_params)
  window.close()
end

M._toggle = function(params)
  window.toggle({ enter = not params.bang })
end

M._save_bundle = function(params)
  task_bundle.save_task_bundle(params.args ~= "" and params.args or nil)
end

M._load_bundle = function(params)
  task_bundle.load_task_bundle(params.args ~= "" and params.args or nil)
end

M._delete_bundle = function(params)
  task_bundle.delete_task_bundle(params.args ~= "" and params.args or nil)
end

M._run_command = function(params)
  if params.args ~= "" then
    M.run_cmd({ cmd = params.args })
  else
    vim.ui.input({
      prompt = "Command:",
    }, function(cmd)
      if cmd then
        M.run_cmd({ cmd = cmd })
      end
    end)
  end
end

M._run_template = function(params)
  local name
  local tags = {}
  for _, str in ipairs(params.fargs) do
    if constants.TAG:contains(str) then
      table.insert(tags, str)
    else
      name = str
    end
  end
  if name and not vim.tbl_isempty(tags) then
    log:error("Cannot find template: %s is not a tag", name)
    return
  end
  local opts = {
    name = name,
    tags = tags,
  }
  M.run_template(opts)
end

M._build_task = function(_params)
  M.build_task()
end

M._quick_action = function(params)
  M.quick_action(params.fargs[1])
end

M._task_action = function(params)
  M.task_action()
end

-- TEMPLATE LOADING/RUNNING

-- Values for prompt:
--   always    Show when template has any params
--   missing   Show when template has any params not provided
--   allow     Only show when required param is missing (default)
--   never     Never show prompt (error if required param missing)
---@class overseer.TemplateRunOpts
---@field name? string The name of the template to run
---@field tags? list|string List of tags used to filter when searching for template
---@field nostart? boolean When true, create the task but do not start it
---@field prompt? "always"|"missing"|"allow"|"never" Controls when to prompt user for parameter input

---@param opts overseer.TemplateRunOpts
---@param params? table Parameters to pass to template
---@param callback? fun(task: overseer.Task)
M.run_template = function(opts, params, callback)
  opts = opts or {}
  vim.validate({
    name = { opts.name, "s", true },
    tags = { opts.tags, "t", true },
    nostart = { opts.nostart, "b", true },
    prompt = { opts.prompt, "s", true },
    params = { params, "t", true },
    callback = { callback, "f", true },
  })
  opts.prompt = opts.prompt or "allow"
  params = params or {}
  local dir = vim.fn.getcwd(0)
  local ft = vim.api.nvim_buf_get_option(0, "filetype")

  local function handle_tmpl(tmpl)
    template.build(tmpl, opts.prompt, params, function(task)
      if task and not opts.nostart then
        task:start()
      end
      if callback then
        callback(task)
      end
    end)
  end

  local tmpl_opts = {
    dir = dir,
    filetype = ft,
    tags = opts.tags,
  }
  if opts.name then
    local tmpl = template.get_by_name(opts.name, tmpl_opts)
    if not tmpl then
      error(string.format("Could not find template '%s'", opts.name))
    end
    handle_tmpl(tmpl)
  else
    local templates = template.list(tmpl_opts)
    if #templates == 0 then
      log:error("Could not find any matching task templates for opts %s", opts)
      return
    elseif #templates == 1 and (opts.name or not vim.tbl_isempty(opts.tags or {})) then
      handle_tmpl(templates[1])
    else
      vim.ui.select(templates, {
        prompt = "Task template:",
        kind = "overseer_template",
        format_item = function(tmpl)
          if tmpl.desc then
            return string.format("%s (%s)", tmpl.name, tmpl.desc)
          else
            return tmpl.name
          end
        end,
      }, function(tmpl)
        if tmpl then
          handle_tmpl(tmpl)
        end
      end)
    end
  end
end

M.run_cmd = function(opts)
  local task = Task.new(opts)
  task:start()
  return task
end

M.build_task = function()
  local task = Task.new({
    name = "New task",
    cmd = { "ls" },
  })
  task_editor.open(task, function(result)
    if result then
      task:start()
    else
      task:dispose()
    end
  end)
end

M.quick_action = function(name)
  if vim.api.nvim_buf_get_option(0, "filetype") == "OverseerList" then
    local sb = sidebar.get_or_create()
    sb:run_action(name)
    return
  end
  local tasks = task_list.list_tasks({ unique = true, recent_first = true })
  local task
  if #tasks == 0 then
    vim.notify("No tasks available", vim.log.levels.WARN)
    return
  else
    task = tasks[1]
  end
  action_util.run_task_action(task)
end

M.task_action = function()
  local tasks = task_list.list_tasks({ unique = true, recent_first = true })
  if #tasks == 0 then
    vim.notify("No tasks available", vim.log.levels.WARN)
    return
  elseif #tasks == 1 then
    action_util.run_task_action(tasks[1])
    return
  end

  vim.ui.select(tasks, {
    prompt = "Select task",
    kind = "overseer_task",
    format_item = function(task)
      return task.name
    end,
  }, function(task)
    if task then
      action_util.run_task_action(task)
    end
  end)
end

return M
