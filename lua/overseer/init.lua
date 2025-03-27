---@diagnostic disable: undefined-doc-param

local M = {}

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
    cmd = "OverseerBuild",
    func = "_build_task",
    def = {
      desc = "Open the task builder",
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
  {
    cmd = "OverseerClearCache",
    func = "_clear_cache",
    def = {
      desc = "Clear the task cache",
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

---Add support for preLaunchTask/postDebugTask to nvim-dap
---@private
---@deprecated
---@param enabled boolean
M.patch_dap = function(enabled)
  M.enable_dap(enabled)
end

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

M.called_setup = false

---Initialize overseer
---@param opts overseer.Config|nil Configuration options
M.setup = function(opts)
  M.called_setup = true
  if vim.fn.has("nvim-0.10") == 0 then
    vim.notify_once(
      "overseer has dropped support for Neovim <0.10. Please use a different branch or upgrade Neovim",
      vim.log.levels.ERROR
    )
    return
  end
  opts = opts or {}
  create_commands()
  M.enable_dap(opts.dap)
  local config = require("overseer.config")
  config.setup(opts)

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
end

---Create a new Task
---@param opts overseer.TaskDefinition
---@return overseer.Task
---@example
--- local task = overseer.new_task({
---   cmd = { "./build.sh" },
---   args = { "all" },
---   components = { { "on_output_quickfix", open = true }, "default" }
--- })
--- task:start()
M.new_task = function(opts)
  return require("overseer.task").new(opts)
end

---Open or close the task list
---@param opts nil|overseer.WindowOpts
M.toggle = function(opts)
  return require("overseer.window").toggle(opts)
end
---Open the task list
---@param opts nil|overseer.WindowOpts
---    enter boolean|nil If false, stay in current window. Default true
---    direction nil|"left"|"right" Which direction to open the task list
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
--- overseer.run_template({name = "make all"})
--- -- Run the default "build" task
--- -- equivalent to :OverseerRun BUILD
--- overseer.run_template({tags = {overseer.TAG.BUILD}})
--- -- Run the task named "serve" with some default parameters
--- overseer.run_template({name = "serve", params = {port = 8080}})
--- -- Create a task but do not start it
--- overseer.run_template({name = "make", autostart = false}, function(task)
---   -- do something with the task
--- end)
--- -- Run a task and immediately open the floating window
--- overseer.run_template({name = "make"}, function(task)
---   if task then
---     overseer.run_action(task, 'open float')
---   end
--- end)
M.run_template = function(opts, callback)
  return require("overseer.commands").run_template(opts, callback)
end

---Preload templates for run_template
---@param opts nil|table
---    dir string
---    ft nil|string
---@param cb nil|fun() Called when preloading is complete
---@note
--- Typically this would be done to prevent a long wait time for :OverseerRun when using a slow
--- template provider.
---@example
--- -- Automatically preload templates for the current directory
--- vim.api.nvim_create_autocmd({"VimEnter", "DirChanged"}, {
---   local cwd = vim.v.cwd or vim.fn.getcwd()
---   require("overseer").preload_task_cache({ dir = cwd })
--- })
M.preload_task_cache = function()
  return require("overseer.commands").preload_cache()
end
---Clear cached templates for run_template
---@param opts? overseer.SearchParams
---    dir string
---    ft nil|string
M.clear_task_cache = function(opts)
  return require("overseer.commands").clear_cache(opts)
end

---Run an action on a task
---@param task overseer.Task
---@param name string|nil Name of action. When omitted, prompt user to pick.
M.run_action = function(task, name)
  return require("overseer.action_util").run_task_action(task, name)
end

---Create a new template by overriding fields on another
---@param base overseer.TemplateFileDefinition The base template definition to wrap
---@param override nil|table<string, any> Override any fields on the base
---@param default_params nil|table<string, any> Provide default values for any parameters on the base
---@return overseer.TemplateFileDefinition
---@note
--- This is typically used for a TemplateProvider, to define the task a single time and generate
--- multiple templates based on the available args.
---@example
--- local tmpl = {
---   params = {
---     args = { type = 'list', delimiter = ' ' }
---   },
---   builder = function(params)
---   return {
---     cmd = { 'make' },
---     args = params.args,
---   }
--- }
--- local template_provider = {
---   name = "Some provider",
---   generator = function(opts, cb)
---     cb({
---       overseer.wrap_template(tmpl, nil, { args = { 'all' } }),
---       overseer.wrap_template(tmpl, {name = 'make clean'}, { args = { 'clean' } }),
---     })
---   end
--- }
M.wrap_template = function(base, override, default_params)
  override = override or {}
  if default_params then
    local base_params = base.params
    if type(base_params) == "function" then
      override.params = function()
        local params = base_params()
        for k, v in pairs(default_params) do
          params[k].default = v
          params[k].optional = true
        end
        return params
      end
    else
      override.params = vim.deepcopy(base_params or {})
      for k, v in pairs(default_params) do
        override.params[k].default = v
        override.params[k].optional = true
      end
    end
  end
  setmetatable(override, { __index = base })
  ---@cast override overseer.TemplateFileDefinition
  return override
end

---Add a hook that runs on a TaskDefinition before the task is created
---@param opts nil|overseer.HookOptions When nil, run the hook on all templates
---    name nil|string Only run if the template name matches this pattern (using string.match)
---    module nil|string Only run if the template module matches this pattern (using string.match)
---    filetype nil|string|string[] Only run if the current file is one of these filetypes
---    dir nil|string|string[] Only run if inside one of these directories
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
---Load a template definition from its module location
---@param name string
---@example
--- -- This will load the template in lua/overseer/template/mytask.lua
--- overseer.load_template('mytask')
M.load_template = function(name)
  require("overseer.template").load_template(name)
end

---Open a tab with windows laid out for debugging a parser
M.debug_parser = function()
  return require("overseer.parser.debug").start_debug_session()
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

setmetatable(M, {
  __index = function(t, key)
    local ok, val = pcall(require, string.format("overseer.%s", key))
    if ok then
      rawset(t, key, val)
      return val
    else
      -- allow top-level direct access to constants (e.g. overseer.STATUS)
      local constants = require("overseer.constants")
      if constants[key] then
        rawset(t, key, constants[key])
        return constants[key]
      end
      error(string.format("Error requiring overseer.%s: %s", key, val))
    end
  end,
})

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

return M
