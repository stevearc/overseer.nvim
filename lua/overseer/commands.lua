local action_util = require("overseer.action_util")
local config = require("overseer.config")
local constants = require("overseer.constants")
local files = require("overseer.files")
local layout = require("overseer.layout")
local log = require("overseer.log")
local sidebar = require("overseer.task_list.sidebar")
local task_bundle = require("overseer.task_bundle")
local task_list = require("overseer.task_list")
local template = require("overseer.template")
local Task = require("overseer.task")
local task_editor = require("overseer.task_editor")
local util = require("overseer.util")
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

M._save_bundle = function(params)
  task_bundle.save_task_bundle(args_or_nil(params.args))
end

M._load_bundle = function(params)
  task_bundle.load_task_bundle(args_or_nil(params.args), { autostart = not params.bang })
end

M._delete_bundle = function(params)
  task_bundle.delete_task_bundle(args_or_nil(params.args))
end

M._info = function(params)
  M.info(function(info)
    local lines = {}
    local highlights = {}
    if info.log.file then
      table.insert(lines, string.format("Log file: %s", info.log.file))
    end
    if info.log.level then
      table.insert(lines, string.format("Log level: %s", info.log.level))
    end
    if not vim.tbl_isempty(info.templates.templates) then
      table.insert(lines, "Individual templates")
      table.insert(highlights, { "Title", #lines, 0, -1 })
    end
    for name, tmpl_report in pairs(info.templates.templates) do
      if tmpl_report.is_present then
        table.insert(lines, string.format("%s: available", name))
      else
        table.insert(lines, string.format("%s: %s", name, tmpl_report.message))
      end
      table.insert(
        highlights,
        { tmpl_report.is_present and "OverseerSUCCESS" or "OverseerFAILURE", #lines, 0, name:len() }
      )
    end
    if not vim.tbl_isempty(info.templates.providers) then
      table.insert(lines, "Template providers")
      table.insert(highlights, { "Title", #lines, 0, -1 })
    end
    for name, provider_report in pairs(info.templates.providers) do
      if provider_report.is_present then
        if provider_report.from_cache then
          name = name .. " (cached)"
        end
        table.insert(
          lines,
          string.format(
            "%s: %d/%d tasks available",
            name,
            provider_report.available_tasks,
            provider_report.total_tasks
          )
        )
      else
        table.insert(lines, string.format("%s: %s", name, provider_report.message))
      end
      table.insert(highlights, {
        provider_report.is_present and provider_report.available_tasks > 0 and "OverseerSUCCESS"
          or "OverseerFAILURE",
        #lines,
        0,
        name:len(),
      })
    end

    local max_width = 0
    for _, line in ipairs(lines) do
      max_width = math.max(max_width, vim.api.nvim_strwidth(line))
    end

    local width = layout.calculate_width(max_width, { min_width = 80, max_width = 0.9 })
    local height = layout.calculate_height(#lines, { min_height = 10, max_height = 0.9 })
    local bufnr = vim.api.nvim_create_buf(false, true)
    local winid = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      border = config.form.border,
      zindex = config.form.zindex,
      width = width,
      height = height,
      col = math.floor((layout.get_editor_width() - width) / 2),
      row = math.floor((layout.get_editor_height() - height) / 2),
      style = "minimal",
    })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = bufnr })
    vim.keymap.set("n", "<C-c>", "<cmd>close<cr>", { buffer = bufnr })
    vim.api.nvim_create_autocmd("BufLeave", {
      desc = "Close info window when leaving buffer",
      buffer = bufnr,
      once = true,
      nested = true,
      callback = function()
        if vim.api.nvim_win_is_valid(winid) then
          vim.api.nvim_win_close(winid, true)
        end
      end,
    })
    local ns = vim.api.nvim_create_namespace("overseer")
    util.add_highlights(bufnr, ns, highlights)
  end)
end

M._run_command = function(params)
  local tmpl_params = {
    cmd = params.args ~= "" and params.args or nil,
  }
  M.run_template({
    name = "shell",
    params = tmpl_params,
  })
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
  M.clear_cache({
    dir = vim.fn.getcwd(),
  })
end

---@param opts table
---    dir string
---    ft nil|string
---@param cb nil|fun Called when preloading is complete
M.preload_cache = function(opts, cb)
  template.list(opts, cb or function() end)
end

---@param opts table
---    dir string
---    ft nil|string
M.clear_cache = template.clear_cache

-- TEMPLATE LOADING/RUNNING

---Options for running a template
---Values for prompt:
---  always    Show when template has any params
---  missing   Show when template has any params not explicitly passed in
---  allow     Only show when a required param is missing
---  avoid     Only show when a required param with no default value is missing
---  never     Never show prompt (error if required param missing)
---@class overseer.TemplateRunOpts
---@field name? string The name of the template to run
---@field tags? string[] List of tags used to filter when searching for template
---@field autostart? boolean When true, start the task after creating it (default true)
---@field first? boolean When true, take first result and never show the task picker. Default behavior will auto-set this based on presence of name and tags
---@field prompt? "always"|"missing"|"allow"|"avoid"|"never" Controls when to prompt user for parameter input
---@field params? table Parameters to pass to template
---@field cwd? string
---@field env? table<string, string>

---@param opts overseer.TemplateRunOpts
---@param callback? fun(task: overseer.Task|nil, err: string|nil)
M.run_template = function(opts, callback)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    autostart = true,
    prompt = config.default_template_prompt,
  })
  vim.validate({
    name = { opts.name, "s", true },
    tags = { opts.tags, "t", true },
    autostart = { opts.autostart, "b", true },
    first = { opts.first, "b", true },
    prompt = { opts.prompt, "s", true },
    params = { opts.params, "t", true },
    callback = { callback, "f", true },
  })
  if opts.first == nil then
    opts.first = opts.name or not vim.tbl_isempty(opts.tags or {})
  end
  opts.params = opts.params or {}
  local dir = vim.fn.getcwd(0)
  local ft = vim.api.nvim_buf_get_option(0, "filetype")
  local search_opts = {
    dir = dir,
    filetype = ft,
    tags = opts.tags,
  }
  opts.search = search_opts

  ---@param tmpl? overseer.TaskDefinition
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
    template.build(tmpl, opts, function(task)
      if task then
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
      if #templates == 0 then
        log:error("Could not find any matching task templates for opts %s", opts)
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

---@param name string Name of action to run
M.quick_action = function(name)
  if vim.api.nvim_buf_get_option(0, "filetype") == "OverseerList" then
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

M.info = function(callback)
  local dir = vim.fn.getcwd(0)
  local ft = vim.api.nvim_buf_get_option(0, "filetype")
  local search_opts = {
    dir = dir,
    filetype = ft,
  }
  local info = {
    log = {
      file = nil,
      level = nil,
    },
    templates = {
      templates = {},
      providers = {},
    },
  }
  local log_levels = vim.deepcopy(vim.log.levels)
  vim.tbl_add_reverse_lookup(log_levels)
  for _, log_conf in ipairs(config.log) do
    if log_conf.type == "file" then
      local ok, stdpath = pcall(vim.fn.stdpath, "log")
      if not ok then
        stdpath = vim.fn.stdpath("cache")
      end
      info.log = {
        file = files.join(stdpath, log_conf.filename),
        level = log_levels[log_conf.level],
      }
      break
    end
  end
  template.list(search_opts, function(_, report)
    info.templates = report
    callback(info)
  end)
end

return M
