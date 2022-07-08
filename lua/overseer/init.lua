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
  vim.cmd(string.format(
    [[
    hi default link OverseerPENDING Normal
    hi default link OverseerRUNNING Constant
    hi default link OverseerSUCCESS %s
    hi default link OverseerCANCELED DiagnosticWarn
    hi default link OverseerFAILURE DiagnosticError
    hi default link OverseerDISPOSED Comment
    hi default link OverseerTask Title
    hi default link OverseerTaskBorder FloatBorder
    hi default link OverseerOutput Normal
    hi default link OverseerComponent Constant
    hi default link OverseerField Keyword
  ]],
    success_color
  ))
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
      local data = string.gsub(vim.json.encode(tasks), "\\/", "/")
      data = string.gsub(data, "'", "\\'")
      table.insert(
        cmds,
        -- For some reason, vim.json.encode encodes / as \/.
        string.format("lua require('overseer')._start_tasks('%s')", data)
      )
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

local function create_commands()
  vim.api.nvim_create_user_command("OverseerOpen", lazy("commands", "_open"), {
    desc = "Open the overseer window",
    nargs = "?",
    bang = true,
    complete = function(arg)
      return vim.tbl_filter(function(dir)
        return vim.startswith(dir, arg)
      end, { "left", "right" })
    end,
  })
  vim.api.nvim_create_user_command("OverseerClose", lazy("commands", "_close"), {
    desc = "Close the overseer window",
  })
  vim.api.nvim_create_user_command("OverseerToggle", lazy("commands", "_toggle"), {
    desc = "Toggle the overseer window",
    nargs = "?",
    bang = true,
    complete = function(arg)
      return vim.tbl_filter(function(dir)
        return vim.startswith(dir, arg)
      end, { "left", "right" })
    end,
  })
  vim.api.nvim_create_user_command("OverseerSaveBundle", lazy("commands", "_save_bundle"), {
    desc = "Serialize the current tasks to disk",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerLoadBundle", lazy("commands", "_load_bundle"), {
    desc = "Load tasks that were serialized to disk",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerDeleteBundle", lazy("commands", "_delete_bundle"), {
    desc = "Delete a saved task bundle",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerRunCmd", lazy("commands", "_run_command"), {
    desc = "Run a raw shell command",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerRun", lazy("commands", "_run_template"), {
    desc = "Run a task from a template",
    nargs = "*",
  })
  vim.api.nvim_create_user_command("OverseerBuild", lazy("commands", "_build_task"), {
    desc = "Build a task from scratch",
  })
  vim.api.nvim_create_user_command("OverseerQuickAction", lazy("commands", "_quick_action"), {
    nargs = "?",
    desc = "Run an action on the most recent task",
  })
  vim.api.nvim_create_user_command("OverseerTaskAction", lazy("commands", "_task_action"), {
    desc = "Select a task to run an action on",
  })
end

M.setup = function(opts)
  create_commands()
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

local function create_wrapper(prefix)
  return function(name, opts)
    return setmetatable(opts, {
      __index = function(t, key)
        if key == "super" then
          local super = require(prefix .. name)
          rawset(t, "super", super)
        else
          return t.super[key]
        end
      end,
    })
  end
end

M.wrap_template = create_wrapper("overseer.template.")

---@param name string
---@param defn? overseer.TemplateDefinition|overseer.TemplateProvider
M.register_template = lazy_pend("template", "register")

-- Used for vim-session integration.
local timer_active = false
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

return M
