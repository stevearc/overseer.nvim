local Task = require("overseer.task")
local action_util = require("overseer.action_util")
local constants = require("overseer.constants")
local log = require("overseer.log")
local sidebar = require("overseer.task_list.sidebar")
local task_editor = require("overseer.task_editor")
local task_list = require("overseer.task_list")
local template = require("overseer.template")
local window = require("overseer.window")

local M = {}

local function args_or_nil(args)
  return args ~= "" and args or nil
end

M._open = function(params)
  window.open({ enter = not params.bang, direction = args_or_nil(params.args) })
end

M._close = function(_params)
  window.close()
end

M._toggle = function(params)
  window.toggle({ enter = not params.bang, direction = args_or_nil(params.args) })
end

M._run_template = function(params)
  local name
  local tags = {}
  for _, str in ipairs(params.fargs) do
    if str == "" then
      -- pass
    elseif constants.TAG:contains(str) then
      table.insert(tags, str)
    else
      name = str
    end
  end
  if name and not vim.tbl_isempty(tags) then
    log.error("Cannot find template: %s is not a tag", name)
    return
  end
  local opts = {
    name = name,
    tags = tags,
  }
  M.run_template(opts, function(_, err)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
  end)
end

M._quick_action = function(params)
  local action_name = params.fargs[1]
  if action_name == "" then
    action_name = nil
  end
  M.quick_action(action_name)
end

M._task_action = function(params)
  M.task_action()
end

M._clear_cache = function(_params)
  M.clear_cache()
end

---@return overseer.SearchParams
local function get_search_params()
  -- If we have a file open, use its parent dir as the search dir.
  -- Otherwise, use the current working directory.
  local dir = vim.fn.getcwd()
  if vim.bo.buftype == "" then
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= "" then
      dir = vim.fn.fnamemodify(bufname, ":p:h")
    end
  end
  return {
    dir = dir,
    filetype = vim.bo.filetype,
  }
end

---@param opts? overseer.SearchParams
---@param cb? fun() Called when preloading is complete
M.preload_cache = function(opts, cb)
  template.list(opts or get_search_params(), cb or function() end)
end

---@param opts? overseer.SearchParams
M.clear_cache = function(opts)
  template.clear_cache(opts or get_search_params())
end

-- TEMPLATE LOADING/RUNNING

---Options for running a template
---@class overseer.TemplateRunOpts
---@field name? string The name of the template to run
---@field tags? string[] List of tags used to filter when searching for template
---@field autostart? boolean When true, start the task after creating it (default true)
---@field first? boolean When true, take first result and never show the task picker. Default behavior will auto-set this based on presence of name and tags
---@field params? table Parameters to pass to template
---@field cwd? string Working directory for the task
---@field env? table<string, string> Additional environment variables for the task
---@field disallow_prompt? boolean When true, if any required parameters are missing return an error instead of prompting the user for them

---@param opts overseer.TemplateRunOpts
---@param callback? fun(task: overseer.Task|nil, err: string|nil)
M.run_template = function(opts, callback)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    autostart = true,
  })
  vim.validate({
    name = { opts.name, "s", true },
    tags = { opts.tags, "t", true },
    autostart = { opts.autostart, "b", true },
    first = { opts.first, "b", true },
    disallow_prompt = { opts.disallow_prompt, "b", true },
    params = { opts.params, "t", true },
    callback = { callback, "f", true },
  })
  if opts.first == nil then
    opts.first = opts.name ~= nil or not vim.tbl_isempty(opts.tags or {})
  end
  local search_opts = get_search_params()
  search_opts.tags = opts.tags

  ---@param tmpl? overseer.TemplateDefinition
  local function handle_tmpl(tmpl)
    if not tmpl then
      local err = "Could not find template"
      if opts.name then
        err = string.format("%s '%s'", err, opts.name)
      end
      if callback then
        callback(nil, err)
      end
      return
    end
    local build_opts = {
      params = opts.params or {},
      search = search_opts,
      disallow_prompt = opts.disallow_prompt,
    }
    template.build_task_args(tmpl, build_opts, function(task_defn)
      local task = nil
      if task_defn then
        if opts.cwd then
          task_defn.cwd = opts.cwd
        end
        if task_defn.env or opts.env then
          task_defn.env = vim.tbl_deep_extend("force", task_defn.env or {}, opts.env or {})
        end
        task = Task.new(task_defn)
        if opts.autostart then
          task:start()
        end
      end
      if callback then
        callback(task)
      end
    end)
  end

  if opts.name and opts.first then
    template.get_by_name(opts.name, search_opts, handle_tmpl)
  else
    template.list(search_opts, function(templates)
      templates = vim.tbl_filter(function(tmpl)
        return not tmpl.hide
      end, templates)

      if #templates == 0 then
        log.error("Could not find any matching task templates for opts %s", opts)
      elseif #templates == 1 or opts.first then
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
    end)
  end
end

---@param name? string Name of action to run
M.quick_action = function(name)
  if vim.bo.filetype == "OverseerList" then
    local sb = sidebar.get_or_create()
    sb:run_action(name)
    return
  end
  local tasks = task_list.list_tasks({ recent_first = true })
  local task
  if #tasks == 0 then
    vim.notify("No tasks available", vim.log.levels.WARN)
    return
  else
    task = tasks[1]
  end
  action_util.run_task_action(task, name)
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

  local task_summaries = vim.tbl_map(function(task)
    return { name = task.name, id = task.id }
  end, tasks)
  vim.ui.select(task_summaries, {
    prompt = "Select task",
    kind = "overseer_task",
    format_item = function(task)
      return task.name
    end,
  }, function(task_summary)
    if task_summary then
      local task = assert(task_list.get(task_summary.id))
      action_util.run_task_action(task)
    end
  end)
end

---@param callback fun(info: overseer.Report)
M.info = function(callback)
  local search_opts = get_search_params()
  template.list(search_opts, function(_, report)
    callback(report)
  end)
end

return M
