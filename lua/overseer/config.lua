---@type overseer.Config
local default_config = {
  -- Default task strategy
  strategy = "terminal",
  -- Template modules to load
  templates = { "builtin" },
  -- When true, tries to detect a green color from your colorscheme to use for success highlight
  auto_detect_success_color = true,
  -- Configure the task list
  task_list = {
    -- Default detail level for tasks. Can be 1-3.
    default_detail = 1,
    -- max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
    max_width = { 100, 0.2 },
    -- min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
    min_width = { 40, 0.1 },
    -- String that separates tasks
    separator = "────────────────────────────────────────",
    -- Default direction. Can be "left" or "right"
    direction = "left",
    bindings = {
      ["?"] = "ShowHelp",
      ["<CR>"] = "RunAction",
      ["<C-e>"] = "Edit",
      ["o"] = "Open",
      ["<C-v>"] = "OpenVsplit",
      ["<C-f>"] = "OpenFloat",
      ["p"] = "TogglePreview",
      ["<C-l>"] = "IncreaseDetail",
      ["<C-h>"] = "DecreaseDetail",
      ["L"] = "IncreaseAllDetail",
      ["H"] = "DecreaseAllDetail",
      ["["] = "DecreaseWidth",
      ["]"] = "IncreaseWidth",
      ["{"] = "PrevTask",
      ["}"] = "NextTask",
    },
  },
  -- TODO: explain these
  actions = {},
  -- Configure the floating window used for task templates that require input
  -- and the floating window used for editing tasks
  form = {
    border = "rounded",
    zindex = 40,
    min_width = 80,
    max_width = 0.9,
    min_height = 10,
    max_height = 0.9,
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 10,
    },
  },
  -- Configure the floating window used for confirmation prompts
  confirm = {
    border = "rounded",
    zindex = 40,
    min_width = 80,
    max_width = 0.5,
    min_height = 10,
    max_height = 0.9,
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 10,
    },
  },
  -- Configuration for task floating windows
  task_win = {
    -- How much space to leave around the floating window
    padding = 2,
    border = "rounded",
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 10,
    },
  },
  -- Aliases for bundles of components. Redefine the builtins, or create your own.
  component_aliases = {
    -- Most tasks are initialized with the default components
    default = {
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "on_restart_handler",
      "dispose_delay",
    },
    -- Used for templates that define a task that should remain running and
    -- restart on failure (e.g. a server or file-watching build process)
    default_persist = {
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "on_restart_handler",
      "on_result_restart",
    },
    -- Used for tasks generated from the VS Code integration (tasks.json)
    default_vscode = {
      "default",
      "on_result_diagnostics",
      "on_result_diagnostics_quickfix",
    },
  },
  -- A list of components to preload on setup.
  -- Only matters if you want them to show up in the task editor.
  preload_components = {},
  -- Configure where the logs go and what level to use
  -- Types are "echo", "notify", and "file"
  log = {
    {
      type = "echo",
      level = vim.log.levels.WARN,
    },
    {
      type = "file",
      filename = "overseer.log",
      level = vim.log.levels.WARN,
    },
  },
}

local M = vim.deepcopy(default_config)

local function merge_actions(default_actions, user_actions)
  local actions = {}
  for k, v in pairs(default_actions) do
    actions[k] = v
  end
  for k, v in pairs(user_actions or {}) do
    if not v then
      actions[k] = nil
    else
      actions[k] = v
    end
  end
  return actions
end

M.setup = function(opts)
  local component = require("overseer.component")
  local log = require("overseer.log")
  local parsers = require("overseer.parsers")
  opts = opts or {}
  local newconf = vim.tbl_deep_extend("force", default_config, opts)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  log.set_root(log.new({ handlers = M.log }))

  M.actions = merge_actions(require("overseer.task_list.actions"), newconf.actions)

  parsers.register_builtin()
  for k, v in pairs(M.component_aliases) do
    component.alias(k, v)
  end
end

return M
