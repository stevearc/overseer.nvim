---@mod overseer
local M = {}

local setup_callbacks = {}

local initialized = false
local pending_opts
local function do_setup()
  if not pending_opts then
    return
  end
  local config = require("overseer.config")
  config.setup(pending_opts)
  pending_opts = nil
  local util = require("overseer.util")
  local success_color = util.find_success_color()
  for _, hl in ipairs(M.get_all_highlights()) do
    vim.cmd(string.format("hi default link %s %s", hl.name, hl.default))
  end
  local aug = vim.api.nvim_create_augroup("Overseer", {})
  if config.auto_detect_success_color then
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "*",
      group = aug,
      desc = "Set Overseer default success color",
      callback = function()
        success_color = util.find_success_color()
        vim.cmd(string.format("hi link OverseerSUCCESS %s", success_color))
      end,
    })
  end
  vim.api.nvim_create_autocmd("User", {
    pattern = "SessionSavePre",
    desc = "Save task state when vim-session saves",
    group = aug,
    callback = function()
      local task_list = require("overseer.task_list")
      local cmds = vim.g.session_save_commands
      local tasks = vim.tbl_map(function(task)
        return task:serialize()
      end, task_list.list_tasks({ bundleable = true }))
      if vim.tbl_isempty(tasks) then
        return
      end
      table.insert(cmds, '" overseer.nvim')
      -- For some reason, vim.json.encode encodes / as \/.
      local data = string.gsub(vim.json.encode(tasks), "\\/", "/")
      data = string.gsub(data, "'", "\\'")
      table.insert(cmds, string.format("lua require('overseer')._start_tasks('%s')", data))
      vim.g.session_save_commands = cmds
    end,
  })
  local Notifier = require("overseer.notifier")
  vim.api.nvim_create_autocmd("FocusGained", {
    desc = "Track editor focus for overseer",
    group = aug,
    callback = function()
      Notifier.focused = true
    end,
  })
  vim.api.nvim_create_autocmd("FocusLost", {
    desc = "Track editor focus for overseer",
    group = aug,
    callback = function()
      Notifier.focused = false
    end,
  })
  local ok, cmp = pcall(require, "cmp")
  if ok then
    cmp.register_source("overseer", require("cmp_overseer").new())
  end
  initialized = true
  for _, cb in ipairs(setup_callbacks) do
    cb()
  end
end

---When this function is called, complete the overseer setup
---@param mod string Name of overseer module
---@param fn string Name of function to wrap
local function lazy(mod, fn)
  return function(...)
    do_setup()
    return require(string.format("overseer.%s", mod))[fn](...)
  end
end

---When this function is called, if overseer has not loaded yet defer the call until after overseer
---has loaded.
---@param mod string Name of overseer module
---@param fn string Name of function to wrap
local function lazy_pend(mod, fn)
  return function(...)
    if initialized then
      require(string.format("overseer.%s", mod))[fn](...)
    else
      local args = { ... }
      M.on_setup(function()
        require(string.format("overseer.%s", mod))[fn](unpack(args))
      end)
    end
  end
end

local commands = {
  {
    cmd = "OverseerOpen",
    args = "`left/right`",
    func = "_open",
    def = {
      desc = "Open the overseer window. With `!` cursor stays in current window",
      nargs = "?",
      bang = true,
      complete = function(arg)
        return vim.tbl_filter(function(dir)
          return vim.startswith(dir, arg)
        end, { "left", "right" })
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
    args = "`left/right`",
    func = "_toggle",
    def = {
      desc = "Toggle the overseer window. With `!` cursor stays in current window",
      nargs = "?",
      bang = true,
      complete = function(arg)
        return vim.tbl_filter(function(dir)
          return vim.startswith(dir, arg)
        end, { "left", "right" })
      end,
    },
  },
  {
    cmd = "OverseerSaveBundle",
    args = "`[name]`",
    func = "_save_bundle",
    def = {
      desc = "Serialize and save the current tasks to disk",
      nargs = "?",
    },
  },
  {
    cmd = "OverseerLoadBundle",
    args = "`[name]`",
    func = "_load_bundle",
    def = {
      desc = "Load tasks that were saved to disk",
      nargs = "?",
    },
  },
  {
    cmd = "OverseerDeleteBundle",
    args = "`[name]`",
    func = "_delete_bundle",
    def = {
      desc = "Delete a saved task bundle",
      nargs = "?",
    },
  },
  {
    cmd = "OverseerRunCmd",
    args = "`[command]`",
    func = "_run_command",
    def = {
      desc = "Run a raw shell command",
      nargs = "?",
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
    cmd = "OverseerInfo",
    func = "_info",
    def = {
      desc = "Display diagnostic information about overseer",
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
    vim.api.nvim_create_user_command(v.cmd, lazy("commands", v.func), v.def)
  end
end

---Add support for preLaunchTask/postDebugTask to nvim-dap
---@param enabled boolean
local function patch_dap(enabled)
  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end
  if type(dap.run) == "table" then
    if not enabled then
      dap.run = dap.run.original
    end
    return
  elseif not enabled then
    return
  end
  local daprun = dap.run
  dap.run = setmetatable({
    wrapper = nil,
    original = daprun,
  }, {
    __call = function(self, config, opts)
      if not self.wrapper then
        self.wrapper = require("overseer.dap").wrap_run(daprun)
      end
      self.wrapper(config, opts)
    end,
  })
end

---Initialize overseer
---@param opts overseer.Config|nil Configuration options
M.setup = function(opts)
  opts = opts or {}
  create_commands()
  patch_dap(opts.dap ~= false)
  pending_opts = opts
  if initialized then
    do_setup()
  end
end

---Add a callback to run after overseer lazy setup
---@param callback fun()
M.on_setup = function(callback)
  if initialized then
    callback()
  else
    table.insert(setup_callbacks, callback)
  end
end

---Create a new Task
---@param opts overseer.TaskDefinition
---    cmd string|string[] Command to run
---    args nil|string[] Arguments to pass to the command
---    name nil|string Name of the task. Defaults to the cmd
---    cwd nil|string Working directory to run in
---    env nil|table<string, string> Additional environment variables
---    strategy nil|overseer.Serialized Definition for a run Strategy
---    metadata nil|table Arbitrary metadata for your own use
---    default_component_params nil|table Default values for component params
---    components nil|overseer.Serialized[] List of components to attach. Defaults to `{'default'}`
---@return overseer.Task
---@example
--- local task = overseer.new_task({
---   cmd = {'./build.sh'},
---   args = {'all'},
---   components = {{'on_output_quickfix', open=true}, 'default'}
--- })
--- task:start()
M.new_task = lazy("task", "new")

---Open or close the task list
---@param opts overseer.WindowOpts|nil
---    enter boolean|nil If false, stay in current window. Default true
---    direction nil|"left"|"right" Which direction to open the task list
M.toggle = lazy("window", "toggle")
---Open the task list
---@param opts overseer.WindowOpts|nil
---    enter boolean|nil If false, stay in current window. Default true
---    direction nil|"left"|"right" Which direction to open the task list
M.open = lazy("window", "open")

---Close the task list
M.close = lazy("window", "close")

---Get the list of saved task bundles
---@return string[] Names of task bundles
M.list_task_bundles = lazy("task_bundle", "list_task_bundles")
---Load tasks from a saved bundle
---@param name string|nil
---@param opts table|nil
---    ignore_missing boolean|nil When true, don't notify if bundle doesn't exist
M.load_task_bundle = lazy("task_bundle", "load_task_bundle")
---Save tasks to a bundle on disk
---@param name string|nil Name of bundle. If nil, will prompt user.
---@param tasks nil|overseer.Task[] Specific tasks to save. If nil, uses config.bundles.save_task_opts
---@param opts table|nil
---    on_conflict nil|"overwrite"|"append"|"cancel"
M.save_task_bundle = lazy("task_bundle", "save_task_bundle")
---Delete a saved task bundle
---@param name string|nil
M.delete_task_bundle = lazy("task_bundle", "delete_task_bundle")

---List all tasks
---@param opts overseer.ListTaskOpts|nil
---    unique boolean|nil Deduplicates non-running tasks by name
---    name nil|string|string[] Only list tasks with this name or names
---    name_not nil|boolean Invert the name search (tasks *without* that name)
---    status nil|overseer.Status|overseer.Status[] Only list tasks with this status or statuses
---    status_not nil|boolean Invert the status search
---    recent_first nil|boolean The most recent tasks are first in the list
---    bundleable nil|boolean Only list tasks that should be included in a bundle
---    filter nil|fun(task: overseer.Task): boolean
---@return overseer.Task[]
M.list_tasks = lazy("task_list", "list_tasks")

---Run a task from a template
---@param opts overseer.TemplateRunOpts
---    name nil|string The name of the template to run
---    tags nil|string[] List of tags used to filter when searching for template
---    autostart nil|boolean When true, start the task after creating it (default true)
---    first nil|boolean When true, take first result and never show the task picker. Default behavior will auto-set this based on presence of name and tags
---    prompt nil|"always"|"missing"|"allow"|"never" Controls when to prompt user for parameter input
---    params nil|table Parameters to pass to template
---    cwd nil|string Working directory for the task
---    env nil|table<string, string> Additional environment variables for the task
---@param callback nil|fun(task: overseer.Task|nil, err: string|nil)
---@note
--- The prompt option will control when the user is presented a popup dialog to input template
--- parameters. The possible values are:
---    always    Show when template has any params
---    missing   Show when template has any params not explicitly passed in
---    allow     Only show when a required param is missing
---    never     Never show prompt (error if required param missing)
--- The default is controlled by the default_template_prompt config option.
---@example
--- -- Run the task named "make all"
--- -- equivalent to :OverseerRun make all
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
--- -- Run a task and always show the parameter prompt
--- overseer.run_template({name = "npm watch", prompt = "always"})
M.run_template = lazy("commands", "run_template")

---Preload templates for run_template
---@param opts table
---    dir string
---    ft nil|string
---@param cb nil|fun Called when preloading is complete
---@note
--- Typically this would be done to prevent a long wait time for :OverseerRun when using a slow
--- template provider.
---@example
--- -- Automatically preload templates for the current directory
--- vim.api.nvim_create_autocmd({"VimEnter", "DirChanged"}, {
---   local cwd = vim.v.cwd or vim.fn.getcwd()
---   require("overseer").preload_task_cache({ dir = cwd })
--- })
M.preload_task_cache = lazy("commands", "preload_cache")
---Clear cached templates for run_template
---@param opts table
---    dir string
---    ft nil|string
M.clear_task_cache = lazy("commands", "clear_cache")

---Run an action on a task
---@param task overseer.Task
---@param name string|nil Name of action. When omitted, prompt user to pick.
M.run_action = lazy("action_util", "run_task_action")

---Create a new template by overriding fields on another
---@param base overseer.TemplateDefinition The base template definition to wrap
---@param override nil|table<string, any> Override any fields on the base
---@param default_params nil|table<string, any> Provide default values for any parameters on the base
---@return overseer.TemplateDefinition
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
    override.params = vim.deepcopy(base.params)
    for k, v in pairs(default_params) do
      override.params[k].default = v
    end
  end
  return setmetatable(override, { __index = base })
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
M.add_template_hook = lazy_pend("template", "add_hook_template")
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
M.remove_template_hook = lazy_pend("template", "remove_hook_template")

---@deprecated
M.hook_template = M.add_template_hook

---Directly register an overseer template
---@param defn overseer.TemplateDefinition|overseer.TemplateProvider
M.register_template = lazy_pend("template", "register")
---Load a template definition from its module location
---@param name string
---@example
--- -- This will load the template in lua/overseer/template/mytask.lua
--- overseer.load_template('mytask')
M.load_template = lazy_pend("template", "load_template")

-- Used for vim-session integration.
local timer_active = false
---@private
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
      local task = M.new_task(params)
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
  local util = require("overseer.util")
  local success_color = util.find_success_color()
  return {
    { name = "OverseerPENDING", default = "Normal", desc = "Pending tasks" },
    { name = "OverseerRUNNING", default = "Constant", desc = "Running tasks" },
    { name = "OverseerSUCCESS", default = success_color, desc = "Succeeded tasks" },
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
