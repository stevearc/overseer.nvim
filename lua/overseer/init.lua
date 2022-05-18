---@mod overseer
local M = {}

local setup_callbacks = {}
M.on_setup = function(callback)
  table.insert(setup_callbacks, callback)
end

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
      local tasks = task_list.serialize_tasks()
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

local function lazy(mod, fn)
  return function(...)
    do_setup()
    return require(string.format("overseer.%s", mod))[fn](...)
  end
end

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

---@param opts overseer.Config
M.setup = function(opts)
  create_commands()
  patch_dap(opts.dap ~= false)
  pending_opts = opts
  if initialized then
    do_setup()
  end
end

M.new_task = lazy("task", "new")

M.toggle = lazy("window", "toggle")
M.open = lazy("window", "open")
M.close = lazy("window", "close")

M.list_task_bundles = lazy("task_bundle", "list_task_bundles")
M.load_task_bundle = lazy("task_bundle", "load_task_bundle")
M.save_task_bundle = lazy("task_bundle", "save_task_bundle")
M.delete_task_bundle = lazy("task_bundle", "delete_task_bundle")

M.run_template = lazy("commands", "run_template")
M.run_cmd = lazy("commands", "run_cmd")

---@param task overseer.Task
---@param name? string Name of action. When omittied, prompt user to pick.
M.run_action = lazy("action_util", "run_task_action")

---@param base overseer.TemplateDefinition
---@param override? table<string, any>
---@param default_params? table<string, any>
---@return overseer.TemplateDefinition
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

---@param defn overseer.TemplateDefinition|overseer.TemplateProvider
M.register_template = lazy_pend("template", "register")

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
