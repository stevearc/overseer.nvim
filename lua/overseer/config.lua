---@type overseer.Config
local default_config = {
  -- Default task strategy
  strategy = "terminal",
  -- Template modules to load
  templates = { "builtin" },
  -- When true, tries to detect a green color from your colorscheme to use for success highlight
  auto_detect_success_color = true,
  -- Patch nvim-dap to support preLaunchTask and postDebugTask
  dap = true,
  -- Configure the task list
  task_list = {
    -- Default detail level for tasks. Can be 1-3.
    default_detail = 1,
    -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_width and max_width can be a single value or a list of mixed integer/float types.
    -- max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
    max_width = { 100, 0.2 },
    -- min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
    min_width = { 40, 0.1 },
    -- optionally define an integer/float for the exact width of the task list
    width = nil,
    -- String that separates tasks
    separator = "────────────────────────────────────────",
    -- Default direction. Can be "left" or "right"
    direction = "left",
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      ["?"] = "ShowHelp",
      ["<CR>"] = "RunAction",
      ["<C-e>"] = "Edit",
      ["o"] = "Open",
      ["<C-v>"] = "OpenVsplit",
      ["<C-s>"] = "OpenSplit",
      ["<C-f>"] = "OpenFloat",
      ["<C-q>"] = "OpenQuickFix",
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
  -- See :help overseer-actions
  actions = {},
  -- Configure the floating window used for task templates that require input
  -- and the floating window used for editing tasks
  form = {
    border = "rounded",
    zindex = 40,
    -- Dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_X and max_X can be a single value or a list of mixed integer/float types.
    min_width = 80,
    max_width = 0.9,
    width = nil,
    min_height = 10,
    max_height = 0.9,
    height = nil,
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 10,
    },
  },
  task_launcher = {
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      i = {
        ["<C-s>"] = "Submit",
        ["<C-c>"] = "Cancel",
      },
      n = {
        ["<CR>"] = "Submit",
        ["<C-s>"] = "Submit",
        ["q"] = "Cancel",
        ["?"] = "ShowHelp",
      },
    },
  },
  task_editor = {
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      i = {
        ["<CR>"] = "NextOrSubmit",
        ["<C-s>"] = "Submit",
        ["<Tab>"] = "Next",
        ["<S-Tab>"] = "Prev",
        ["<C-c>"] = "Cancel",
      },
      n = {
        ["<CR>"] = "NextOrSubmit",
        ["<C-s>"] = "Submit",
        ["<Tab>"] = "Next",
        ["<S-Tab>"] = "Prev",
        ["q"] = "Cancel",
        ["?"] = "ShowHelp",
      },
    },
  },
  -- Configure the floating window used for confirmation prompts
  confirm = {
    border = "rounded",
    zindex = 40,
    -- Dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_X and max_X can be a single value or a list of mixed integer/float types.
    min_width = 20,
    max_width = 0.5,
    width = nil,
    min_height = 6,
    max_height = 0.9,
    height = nil,
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
      { "display_duration", detail_level = 2 },
      "on_output_summarize",
      "on_exit_set_status",
      "on_complete_notify",
      "on_complete_dispose",
    },
    -- Tasks from tasks.json use these components
    default_vscode = {
      "default",
      "on_result_diagnostics",
      "on_result_diagnostics_quickfix",
    },
  },
  bundles = {
    -- When saving a bundle with OverseerSaveBundle or save_task_bundle(), filter the tasks with
    -- these options (passed to list_tasks())
    save_task_opts = {
      bundleable = true,
    },
  },
  -- A list of components to preload on setup.
  -- Only matters if you want them to show up in the task editor.
  preload_components = {},
  -- Controls when the parameter prompt is shown when running a template
  --   always    Show when template has any params
  --   missing   Show when template has any params not explicitly passed in
  --   allow     Only show when a required param is missing
  --   avoid     Only show when a required param with no default value is missing
  --   never     Never show prompt (error if required param missing)
  default_template_prompt = "allow",
  -- For template providers, how long to wait (in ms) before timing out.
  -- Set to 0 to disable timeouts.
  template_timeout = 3000,
  -- Cache template provider results if the provider takes longer than this to run.
  -- Time is in ms. Set to 0 to disable caching.
  template_cache_threshold = 100,
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

---If user creates a mapping for an action, remove the default mapping to that action
---(unless they explicitly specify that key as well)
---@param user_conf overseer.Config
local function remove_binding_conflicts(user_conf)
  for key, configval in pairs(user_conf) do
    if type(configval) == "table" and configval.bindings then
      local orig_bindings = default_config[key].bindings
      local rev = {}
      -- Make a reverse lookup of shortcut-to-key
      -- e.g. ["Open"] = "o"
      for k, v in pairs(orig_bindings) do
        rev[v] = k
      end
      for k, v in pairs(configval.bindings) do
        -- If the user is choosing to map a command to a different key, remove the original default
        -- map (e.g. if {"u" = "Open"}, then set {"o" = false})
        if rev[v] and rev[v] ~= k and not configval.bindings[rev[v]] then
          configval.bindings[rev[v]] = false
        end
      end
    end
  end
end

---@param opts? overseer.Config
M.setup = function(opts)
  local overseer = require("overseer")
  local component = require("overseer.component")
  local log = require("overseer.log")
  opts = opts or {}
  remove_binding_conflicts(opts)
  local newconf = vim.tbl_deep_extend("force", default_config, opts)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  log.set_root(log.new({ handlers = M.log }))

  M.actions = merge_actions(require("overseer.task_list.actions"), newconf.actions)

  for k, v in pairs(M.component_aliases) do
    component.alias(k, v)
  end

  -- Deprecated option
  if newconf.pre_task_hook then
    vim.notify_once(
      "Overseer pre_task_hook is deprecated. Use overseer.add_template_hook\nThis option will be removed on 2023-02-01",
      vim.log.levels.WARN
    )
    overseer.add_template_hook(nil, newconf.pre_task_hook)
  end
end

return M
