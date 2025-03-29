local default_config = {
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
    max_height = { 20, 0.1 },
    min_height = 8,
    height = nil,
    -- String that separates tasks
    separator = "────────────────────────────────────────",
    -- Default direction. Can be "left", "right", or "bottom"
    direction = "bottom",
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      ["?"] = "ShowHelp",
      ["g?"] = "ShowHelp",
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
      ["<C-k>"] = "ScrollOutputUp",
      ["<C-j>"] = "ScrollOutputDown",
      ["q"] = "Close",
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
      winblend = 0,
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
  -- Configuration for task floating windows
  task_win = {
    -- How much space to leave around the floating window
    padding = 2,
    border = "rounded",
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 0,
    },
  },
  -- Configuration for mapping help floating windows
  help_win = {
    border = "rounded",
    win_opts = {},
  },
  -- Aliases for bundles of components. Redefine the builtins, or create your own.
  component_aliases = {
    -- Most tasks are initialized with the default components
    default = {
      { "display_duration", detail_level = 2 },
      "on_output_summarize",
      "on_exit_set_status",
      "on_complete_notify",
      { "on_complete_dispose", require_view = { "SUCCESS", "FAILURE" } },
    },
    -- Tasks from tasks.json use these components
    default_vscode = {
      "default",
      "on_result_diagnostics",
    },
  },
  -- For template providers, how long to wait (in ms) before timing out.
  -- Set to 0 to wait forever.
  template_timeout = 3000,
  -- Cache template provider results if the provider takes longer than this to run.
  -- Time is in ms. Set to 0 to disable caching.
  template_cache_threshold = 200,
  log_level = vim.log.levels.WARN,
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
  opts = opts or {}
  remove_binding_conflicts(opts)
  local newconf = vim.tbl_deep_extend("force", default_config, opts)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  M.actions = merge_actions(require("overseer.task_list.actions"), newconf.actions)
end

---@class (exact) overseer.Config
---@field strategy? overseer.Serialized Default task strategy
---@field auto_detect_success_color? boolean
---@field dap? boolean Patch nvim-dap to support preLaunchTask and postDebugTask
---@field task_list? overseer.ConfigTaskList Configure the task list
---@field actions? any See :help overseer-actions
---@field form? overseer.ConfigFloatWin Configure the floating window used for task templates that require input and the floating window used for editing tasks
---@field task_launcher? table
---@field task_editor? table
---@field task_win? overseer.ConfigTaskWin
---@field help_win? overseer.ConfigFloatWin
---@field component_aliases? table<string, overseer.Serialized[]> Aliases for bundles of components. Redefine the builtins, or create your own.
---@field template_timeout? integer For template providers, how long to wait (in ms) before timing out. Set to 0 to disable timeouts.
---@field template_cache_threshold? integer Cache template provider results if the provider takes longer than this to run. Time is in ms. Set to 0 to disable caching.
---@field log? table[]

---@class (exact) overseer.ConfigTaskList
---@field default_detail? 1|2|3 Default detail level for tasks. Can be 1-3.
---@field max_width? number|number[] Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%). min_width and max_width can be a single value or a list of mixed integer/float types. max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
---@field min_width? number|number[] min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
---@field width? number optionally define an integer/float for the exact width of the task list
---@field max_height? number|number[]
---@field min_height? number|number[]
---@field height? number
---@field separator? string String that separates tasks
---@field direction? string Default direction. Can be "left", "right", or "bottom"
---@field bindings? table<string, string|false> Set keymap to false to remove default behavior

---@class (exact) overseer.ConfigFloatWin
---@field border? string|table
---@field zindex? integer
---@field min_width? number|number[]
---@field max_width? number|number[]
---@field min_height? number|number[]
---@field max_height? number|number[]
---@field win_opts? table<string, any>

---@class (exact) overseer.ConfigTaskWin
---@field border? string|table
---@field padding? integer
---@field win_opts? table<string, any>

return M
