local M = {}

---@alias overseer.Serialized string|{[1]: string, [string]: any}

local commands = {
  {
    cmd = "OverseerOpen",
    args = "`left/right/bottom`",
    func = "_open",
    def = {
      desc = "Open the overseer window. With `!` cursor stays in current window",
      nargs = "?",
      bang = true,
      complete = function(arg)
        return vim.tbl_filter(function(dir)
          return vim.startswith(dir, arg)
        end, { "left", "right", "bottom" })
      end,
    },
  },
  {
    cmd = "OverseerClose",
    func = "_close",
    def = {
      desc = "Close the overseer window",
    },
  },
  {
    cmd = "OverseerToggle",
    args = "`left/right/bottom`",
    func = "_toggle",
    def = {
      desc = "Toggle the overseer window. With `!` cursor stays in current window",
      nargs = "?",
      bang = true,
      complete = function(arg)
        return vim.tbl_filter(function(dir)
          return vim.startswith(dir, arg)
        end, { "left", "right", "bottom" })
      end,
    },
  },
  {
    cmd = "OverseerRun",
    args = "`[name/tags]`",
    func = "_run_template",
    def = {
      desc = "Run a task from a template",
      nargs = "*",
    },
  },
  {
    cmd = "OverseerShell",
    args = "`[command]`",
    func = "_run_shell",
    def = {
      desc = "Run a shell command as an overseer task",
      complete = "shellcmdline",
      nargs = "*",
    },
  },
  {
    cmd = "OverseerQuickAction",
    args = "`[action]`",
    func = "_quick_action",
    def = {
      nargs = "?",
      desc = "Run an action on the most recent task, or the task under the cursor",
    },
  },
  {
    cmd = "OverseerTaskAction",
    func = "_task_action",
    def = {
      desc = "Select a task to run an action on",
    },
  },
}

local function create_commands()
  for _, v in pairs(commands) do
    vim.api.nvim_create_user_command(v.cmd, function(args)
      require("overseer.commands")[v.func](args)
    end, v.def)
  end
end

M.builtin = {
  jobstart = vim.fn.jobstart,
  system = vim.system,
}

---Add support for preLaunchTask/postDebugTask to nvim-dap
---This is enabled by default when you call overseer.setup() unless you set `dap = false`
---@param enabled? boolean
M.enable_dap = function(enabled)
  if enabled == nil then
    enabled = true
  end
  if not enabled and not package.loaded.dap then
    return
  end
  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end
  if not dap.listeners.on_config then
    local log = require("overseer.log")
    log.warn("overseer requires a newer version of nvim-dap to enable DAP integration")
    return
  end
  if enabled then
    dap.listeners.on_config.overseer = require("overseer.dap").listener

    -- If the user has not overridden the DAP json decoder, use ours since it supports JSON5
    local vscode = require("dap.ext.vscode")
    if vscode.json_decode == vim.json.decode then
      vscode.json_decode = require("overseer.json").decode
    end
  else
    dap.listeners.on_config.overseer = nil
    dap.listeners.after.event_terminated.overseer = nil
  end
end

---Initialize overseer
---@param opts overseer.SetupOpts|nil Configuration options
M.setup = function(opts)
  opts = opts or {}
  if not M.private_setup() then
    return
  end
  local config = require("overseer.config")
  config.setup(opts)
  M.enable_dap(config.dap)
  M.wrap_builtins(config.wrap_builtins.enabled)
end

local did_setup = false
---@private
---@return boolean
M.private_setup = function()
  if vim.fn.has("nvim-0.11") == 0 then
    vim.notify_once(
      "overseer has dropped support for Neovim <0.11. Please use a different branch or upgrade Neovim",
      vim.log.levels.ERROR
    )
    return false
  end

  if did_setup then
    return true
  end
  did_setup = true

  create_commands()
  M.wrap_builtins()
  for _, hl in ipairs(M.get_all_highlights()) do
    vim.api.nvim_set_hl(0, hl.name, { link = hl.default, default = true })
  end
  local aug = vim.api.nvim_create_augroup("Overseer", {})
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    group = aug,
    desc = "Update Overseer highlights",
    callback = function()
      for _, hl in ipairs(M.get_all_highlights()) do
        vim.api.nvim_set_hl(0, hl.name, { link = hl.default, default = true })
      end
    end,
  })
  return true
end

---Create a new Task
---@param opts overseer.TaskDefinition
---@return overseer.Task
---@example
--- local task = overseer.new_task({
---   cmd = { "./build.sh", "all" },
---   components = { { "on_output_quickfix", open = true }, "default" }
--- })
--- task:start()
M.new_task = function(opts)
  ---@diagnostic disable-next-line: invisible
  local data = opts.from_template
  if data then
    local template = require("overseer.template")
    local tmpl
    local done = false
    template.get_by_name(data.name, data.search, function(t)
      tmpl = t
      done = true
    end)
    vim.wait(2000, function()
      return done
    end)
    if not tmpl then
      error(string.format("Could not find template '%s'", data.name))
    end
    local task
    done = false
    local build_opts = {
      params = data.params,
      env = data.env,
      cwd = opts.cwd,
      search = data.search,
      disallow_prompt = true,
    }
    template.build_task(tmpl, build_opts, function(_, t)
      done = true
      task = t
    end)
    vim.wait(500, function()
      return done
    end)
    if not task then
      error(string.format("Error building task from template '%s'", data.name))
    end
    return task
  else
    return require("overseer.task").new(opts)
  end
end

---@class (exact) overseer.RunCmdOpts
---@field autostart? boolean

---@param opts? overseer.RunCmdOpts
---@param callback? fun(task: nil|overseer.Task)
M.run_cmd = function(opts, callback)
  opts = vim.tbl_extend("keep", opts or {}, { autostart = true })
  vim.ui.input({ prompt = "command", completion = "shellcmdline" }, function(cmd)
    if not cmd then
      if callback then
        callback()
      end
      return
    end
    local task = M.new_task({ cmd = cmd })
    if opts.autostart then
      task:start()
    end
    if callback then
      callback(task)
    end
  end)
end

---Open or close the task list
---@param opts nil|overseer.WindowOpts
M.toggle = function(opts)
  return require("overseer.window").toggle(opts)
end
---Open the task list
---@param opts nil|overseer.WindowOpts
M.open = function(opts)
  return require("overseer.window").open(opts)
end

---Close the task list
M.close = function()
  return require("overseer.window").close()
end

---List all tasks
---@param opts nil|overseer.ListTaskOpts
---@return overseer.Task[]
M.list_tasks = function(opts)
  return require("overseer.task_list").list_tasks(opts)
end

---Run a task from a template
---@param opts overseer.TemplateRunOpts
---@param callback nil|fun(task: overseer.Task|nil, err: string|nil)
---@example
--- -- Run the task named "make all"
--- -- equivalent to :OverseerRun make\ all
--- overseer.run_task({name = "make all"})
--- -- Run the default "build" task
--- -- equivalent to :OverseerRun BUILD
--- overseer.run_task({tags = {overseer.TAG.BUILD}})
--- -- Run the task named "serve" with some default parameters
--- overseer.run_task({name = "serve", params = {port = 8080}})
--- -- Create a task but do not start it
--- overseer.run_task({name = "make", autostart = false}, function(task)
---   -- do something with the task
--- end)
--- -- Run a task and immediately open the floating window
--- overseer.run_task({name = "make"}, function(task)
---   if task then
---     overseer.run_action(task, 'open float')
---   end
--- end)
M.run_task = function(opts, callback)
  return require("overseer.commands").run_template(opts, callback)
end

---Use overseer.run_task
---@deprecated
M.run_template = function(opts, callback)
  vim.deprecate("overseer.run_template", "overseer.run_task", "2026-01-01", "overseer.nvim")
  return M.run_task(opts, callback)
end

---Preload templates for run_task
---@param opts? overseer.SearchParams
---@param cb? fun() Called when preloading is complete
---@note
--- Typically this would be done to prevent a long wait time for :OverseerRun when using a slow
--- template provider.
---@example
--- -- Automatically preload templates for the current directory
--- vim.api.nvim_create_autocmd({"VimEnter", "DirChanged"}, {
---   local cwd = vim.v.cwd or vim.fn.getcwd()
---   require("overseer").preload_task_cache({ dir = cwd })
--- })
M.preload_task_cache = function(opts, cb)
  return require("overseer.commands").preload_cache(opts, cb)
end
---Clear cached templates for run_task
---@param opts? overseer.SearchParams
M.clear_task_cache = function(opts)
  return require("overseer.commands").clear_cache(opts)
end

---Run an action on a task
---@param task overseer.Task
---@param name string|nil Name of action. When omitted, prompt user to pick.
M.run_action = function(task, name)
  return require("overseer.action_util").run_task_action(task, name)
end

---Add a hook that runs on a TaskDefinition before the task is created
---@param opts nil|overseer.HookOptions When nil, run the hook on all templates
---@param hook fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)
---@example
--- -- Add on_output_quickfix component to all "cargo" templates
--- overseer.add_template_hook({ module = "^cargo$" }, function(task_defn, util)
---   util.add_component(task_defn, { "on_output_quickfix", open = true })
--- end)
--- -- Remove the on_complete_notify component from "cargo clean" task
--- overseer.add_template_hook({ name = "cargo clean" }, function(task_defn, util)
---   util.remove_component(task_defn, "on_complete_notify")
--- end)
--- -- Add an environment variable for all go tasks in a specific dir
--- overseer.add_template_hook({ name = "^go .*", dir = "/path/to/project" }, function(task_defn, util)
---   task_defn.env = vim.tbl_extend('force', task_defn.env or {}, {
---     GO111MODULE = "on"
---   })
--- end)
M.add_template_hook = function(opts, hook)
  require("overseer.template").add_hook_template(opts, hook)
end
---Remove a hook that was added with add_template_hook
---@param opts nil|overseer.HookOptions Same as for add_template_hook
---@param hook fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)
---@example
--- local opts = {module = "cargo"}
--- local hook = function(task_defn, util)
---   util.add_component(task_defn, { "on_output_quickfix", open = true })
--- end
--- overseer.add_template_hook(opts, hook)
--- -- Remove should pass in the same opts as add
--- overseer.remove_template_hook(opts, hook)
M.remove_template_hook = function(opts, hook)
  require("overseer.template").remove_hook_template(opts, hook)
end

---Directly register an overseer template
---@param defn overseer.TemplateDefinition|overseer.TemplateProvider
---@example
--- overseer.register_template({
---   name = "My Task",
---   builder = function(params)
---     return {
---       cmd = { "echo", "Hello", "world" },
---     }
---   end,
--- })
M.register_template = function(defn)
  require("overseer.template").register(defn)
end

---Register a new component alias.
---@param name string
---@param components overseer.Serialized[]
---@note
--- This is intended to be used by plugin authors that wish to build on top of overseer. They do not
--- have control over the call to overseer.setup(), so this provides an alternative method of
--- setting a component alias that they can then use when creating tasks.
---@example
--- require("overseer").register_alias("my_plugin", { "default", "on_output_quickfix" })
M.register_alias = function(name, components)
  return require("overseer.component").alias(name, components)
end

---Set a window to display the output of a dynamically-chosen task
---@param winid? integer The window to use for displaying the task output
---@param opts? overseer.TaskViewOpts
---@example
--- -- Always show the output from the most recent Neotest task in this window.
--- -- Close it automatically when all test tasks are disposed.
--- overseer.create_task_output_view(0, {
---   select = function(self, tasks, task_under_cursor)
---     for _, task in ipairs(tasks) do
---       if task.metadata.neotest_group_id then
---         return task
---       end
---     end
---     self:dispose()
---   end,
--- })
M.create_task_output_view = function(winid, opts)
  require("overseer.task_view").new(winid, opts)
end

---@param cmd string|string[]
---@param opts? table
---@return any
local wrapped_jobstart = function(cmd, opts)
  local config = require("overseer.config")
  local util = require("overseer.util")
  local caller = util.get_caller()
  -- TODO wrapping jobstart in a fast event is difficult because we call a lot of unsafe APIs
  if vim.in_fast_event() or not config.wrap_builtins.condition(cmd, caller, opts) then
    return M.builtin.jobstart(cmd, opts)
  end
  opts = opts or {}
  local task = M.new_task({
    cmd = cmd,
    cwd = opts.cwd,
    env = opts.env,
    source = caller,
    ephemeral = true,
    strategy = { "jobstart", wrap_opts = opts },
    components = { "default_builtin" },
  })
  task:start()
  local strat = task.strategy
  ---@cast strat overseer.JobstartStrategy
  return strat.job_id
end
---@param cmd string[]
---@param opts? vim.SystemOpts
---@param on_exit? fun(out: vim.SystemCompleted)
---@return vim.SystemObj
local wrapped_system = function(cmd, opts, on_exit)
  local config = require("overseer.config")
  local util = require("overseer.util")
  local caller = util.get_caller()
  -- TODO wrapping vim.system in a fast event is difficult because we call a lot of unsafe APIs
  if vim.in_fast_event() or not config.wrap_builtins.condition(cmd, caller, opts) then
    return M.builtin.system(cmd, opts, on_exit)
  end
  opts = opts or {}
  local task = M.new_task({
    cmd = cmd,
    cwd = opts.cwd,
    ---@diagnostic disable-next-line: assign-type-mismatch
    env = opts.env,
    source = caller,
    ephemeral = true,
    strategy = { "system", wrap_opts = opts, wrap_exit = on_exit },
    components = { "default_builtin" },
  })
  task:start()
  local strat = task.strategy
  ---@cast strat overseer.SystemStrategy
  return strat.handle
end

local patched = false
---Hook vim.system and vim.fn.jobstart to display tasks in overseer
---@param enabled? boolean
M.wrap_builtins = function(enabled)
  if enabled == nil then
    enabled = true
  end
  if patched == enabled then
    return
  end
  patched = enabled

  if patched then
    vim.fn.jobstart = wrapped_jobstart
    vim.system = wrapped_system
  else
    vim.fn.jobstart = M.builtin.jobstart
    vim.system = M.builtin.system
  end
end

---Used for documentation generation
---@private
M.get_all_commands = function()
  local cmds = vim.deepcopy(commands)
  for _, v in ipairs(cmds) do
    -- Remove all function values from the command definition so we can serialize it
    for k, param in pairs(v.def) do
      if type(param) == "function" then
        v.def[k] = nil
      end
    end
  end
  return cmds
end

---Used for documentation generation
---@private
M.get_all_highlights = function()
  return {
    { name = "OverseerPENDING", default = "Normal", desc = "Pending tasks" },
    { name = "OverseerRUNNING", default = "Constant", desc = "Running tasks" },
    { name = "OverseerSUCCESS", default = "DiagnosticOk", desc = "Succeeded tasks" },
    { name = "OverseerCANCELED", default = "DiagnosticWarn", desc = "Canceled tasks" },
    { name = "OverseerFAILURE", default = "DiagnosticError", desc = "Failed tasks" },
    { name = "OverseerDISPOSED", default = "Comment" },
    {
      name = "OverseerTask",
      default = "Title",
      desc = "Used to render the name of a task or template",
    },
    {
      name = "OverseerTaskBorder",
      default = "FloatBorder",
      desc = "The separator in the task list",
    },
    { name = "OverseerOutput", default = "Normal", desc = "The output summary in the task list" },
    {
      name = "OverseerComponent",
      default = "Constant",
      desc = "The name of a component in the task list or task editor",
    },
    {
      name = "OverseerField",
      default = "Keyword",
      desc = "The name of a field in the task or template editor",
    },
  }
end

setmetatable(M, {
  __index = function(t, key)
    -- allow top-level direct access to constants (e.g. overseer.STATUS)
    local constants = require("overseer.constants")
    if constants[key] then
      rawset(t, key, constants[key])
      return constants[key]
    end
    return rawget(t, key)
  end,
})

return M
