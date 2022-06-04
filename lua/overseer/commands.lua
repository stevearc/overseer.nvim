local action_util = require("overseer.action_util")
local constants = require("overseer.constants")
local sidebar = require("overseer.task_list.sidebar")
local task_bundle = require("overseer.task_bundle")
local task_list = require("overseer.task_list")
local template = require("overseer.template")
local Task = require("overseer.task")
local task_editor = require("overseer.task_editor")
local window = require("overseer.window")

local M = {}

M.create_commands = function()
  vim.api.nvim_create_user_command("OverseerOpen", function()
    window.open()
  end, {
    desc = "Open the overseer window",
  })
  vim.api.nvim_create_user_command("OverseerClose", function()
    window.close()
  end, {
    desc = "Close the overseer window",
  })
  vim.api.nvim_create_user_command("OverseerToggle", function()
    window.toggle()
  end, {
    desc = "Toggle the overseer window",
  })
  vim.api.nvim_create_user_command("OverseerSaveBundle", function(params)
    task_bundle.save_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Serialize the current tasks to disk",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerLoadBundle", function(params)
    task_bundle.load_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Load tasks that were serialized to disk",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerDeleteBundle", function(params)
    task_bundle.delete_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Delete a saved task bundle",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerRunCmd", function(params)
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
  end, {
    desc = "Run a raw shell command",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerRun", function(params)
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
      vim.notify(string.format("Cannot find template: %s is not a tag", name), vim.log.levels.ERROR)
      return
    end
    local opts = {
      name = name,
      tags = tags,
    }
    M.run_template(opts)
  end, {
    desc = "Run a task from a template",
    nargs = "*",
  })
  vim.api.nvim_create_user_command("OverseerBuild", M.build_task, {
    desc = "Build a task from scratch",
  })
  vim.api.nvim_create_user_command("OverseerQuickAction", function(params)
    M.quick_action(params.fargs[1])
  end, {
    nargs = "?",
    desc = "Run an action on the most recent task",
  })
  vim.api.nvim_create_user_command("OverseerTaskAction", function(params)
    M.task_action()
  end, {
    desc = "Select a task to run an action on",
  })
end

-- TEMPLATE LOADING/RUNNING

-- @param name (string) The name of the template to run
-- @param tags (list|string) List of tags used to filter when searching for template
-- @param nostart (bool) When true, create the task but do not start it
-- @param prompt (string) Controls when to prompt user for parameter input
--            always    Show when template has any params
--            missing   Show when template has any params not provided (default)
--            allow     Only show when required param is missing
--            never     Never show prompt (error if required param missing)
-- @param params (table) Parameters to pass to template
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
  opts.prompt = opts.prompt or "missing"
  params = params or {}
  local dir = vim.fn.getcwd(0)
  local ft = vim.api.nvim_buf_get_option(0, "filetype")

  local function handle_tmpl(tmpl)
    tmpl:build(opts.prompt, params, function(task)
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
      vim.notify("Could not find any matching task templates", vim.log.levels.ERROR)
      return
    elseif #templates == 1 and (opts.name or not vim.tbl_isempty(opts.tags or {})) then
      handle_tmpl(templates[1])
    else
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
