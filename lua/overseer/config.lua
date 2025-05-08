local default_config = {
  -- Patch nvim-dap to support preLaunchTask and postDebugTask
  dap = true,
  -- Overseer can wrap any call to vim.system and vim.fn.jobstart as a task.
  wrap_builtins = {
    enabled = false,
    condition = function(cmd, caller, opts)
      return true
    end,
  },
  -- Configure the task list
  task_list = {
    -- Default direction. Can be "left", "right", or "bottom"
    direction = "bottom",
    -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_width and max_width can be a single value or a list of mixed integer/float types.
    -- max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
    max_width = { 100, 0.2 },
    -- min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
    min_width = { 40, 0.1 },
    max_height = { 20, 0.2 },
    min_height = 8,
    -- String that separates tasks
    separator = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    -- Indentation for child tasks
    child_indent = { "┃ ", "┣━", "┗━" },
    -- Function that renders tasks. See lua/overseer/render.lua for built-in options
    -- and for useful functions if you want to build your own.
    render = function(task)
      return require("overseer.render").format_standard(task)
    end,
    -- The sort function for tasks
    sort = function(a, b)
      return require("overseer.task_list").default_sort(a, b)
    end,
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    keymaps = {
      ["?"] = "actions.show_help",
      ["g?"] = "actions.show_help",
      ["<CR>"] = "actions.run_action",
      ["dd"] = { "actions.run_action", opts = { action = "dispose" }, desc = "Dispose task" },
      ["<C-e>"] = { "actions.run_action", opts = { action = "edit" }, desc = "Edit task" },
      ["o"] = "actions.open",
      ["<C-v>"] = { "actions.open", opts = { dir = "vsplit" }, desc = "Open task output in vsplit" },
      ["<C-s>"] = { "actions.open", opts = { dir = "split" }, desc = "Open task output in split" },
      ["<C-t>"] = { "actions.open", opts = { dir = "tab" }, desc = "Open task output in tab" },
      ["<C-f>"] = { "actions.open", opts = { dir = "float" }, desc = "Open task output in float" },
      ["<C-q>"] = {
        "actions.run_action",
        opts = { action = "open output in quickfix" },
        desc = "Open task output in the quickfix",
      },
      ["p"] = "actions.toggle_preview",
      ["{"] = "actions.prev_task",
      ["}"] = "actions.next_task",
      ["<C-k>"] = "actions.scroll_output_up",
      ["<C-j>"] = "actions.scroll_output_down",
      ["g."] = "actions.toggle_show_wrapped",
      ["q"] = { "<CMD>close<CR>", desc = "Close task list" },
    },
  },
  -- Custom actions for tasks. See :help overseer-actions
  actions = {},
  -- Configure the floating window used for task templates that require input
  -- and the floating window used for editing tasks
  form = {
    zindex = 40,
    -- Dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_X and max_X can be a single value or a list of mixed integer/float types.
    min_width = 80,
    max_width = 0.9,
    min_height = 10,
    max_height = 0.9,
    -- Set any window options here (e.g. winhighlight)
    win_opts = {},
  },
  -- Configuration for task floating output windows
  task_win = {
    -- How much space to leave around the floating window
    padding = 2,
    -- Set any window options here (e.g. winhighlight)
    win_opts = {},
  },
  -- Aliases for bundles of components. Redefine the builtins, or create your own.
  component_aliases = {
    -- Most tasks are initialized with the default components
    default = {
      "on_exit_set_status",
      "on_complete_notify",
      { "on_complete_dispose", require_view = { "SUCCESS", "FAILURE" } },
    },
    -- Tasks from tasks.json use these components
    default_vscode = {
      "default",
      "on_result_diagnostics",
    },
    -- Tasks created from vim.system or vim.fn.jobstart
    default_builtin = {
      "on_exit_set_status",
      "on_complete_dispose",
      { "unique", soft = true },
    },
  },
  -- List of other directories to search for task templates.
  -- This will search under the runtimepath, so for example
  -- "foo/bar" will search "<runtimepath>/lua/foo/bar/*"
  template_dirs = {},
  -- For template providers, how long to wait before timing out.
  -- Set to 0 to wait forever.
  template_timeout_ms = 3000,
  -- Cache template provider results if the provider takes longer than this to run.
  -- Set to 0 to disable caching.
  template_cache_threshold_ms = 200,
  log_level = vim.log.levels.WARN,
}

local M = {}

local has_setup = false
---@param opts? overseer.SetupOpts
M.setup = function(opts)
  has_setup = true
  opts = opts or {}

  local newconf = vim.tbl_deep_extend("force", default_config, opts)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  if opts.task_list and opts.task_list.keymaps then
    -- Handle keymap overrides in a case-insensitive way
    local case_map = {}
    for k in pairs(default_config.task_list.keymaps) do
      case_map[k:lower()] = k
    end
    newconf.task_list.keymaps = vim.deepcopy(default_config.task_list.keymaps)
    -- We don't want to deep merge the keymaps, we want any keymap defined by the user to override
    -- everything about the default.
    for k, v in pairs(opts.task_list.keymaps) do
      k = case_map[k:lower()] or k
      if v then
        newconf.task_list.keymaps[k] = v
      else
        newconf.task_list.keymaps[k] = nil
      end
    end
  end

  for i, dir in ipairs(M.template_dirs) do
    -- for backwards compatibility, we used to allow module paths
    M.template_dirs[i] = dir:gsub("%.", "/")
  end
end

---@class (exact) overseer.Config
---@field setup fun(opts: overseer.SetupOpts)
---@field dap boolean
---@field log_level integer
---@field wrap_builtins overseer.ConfigWrapBuiltins
---@field task_list overseer.ConfigTaskList
---@field actions table<string, false|overseer.Action> See :help overseer-actions
---@field form overseer.ConfigFloatWin
---@field task_win overseer.ConfigTaskWin
---@field component_aliases table<string, overseer.Serialized[]> Aliases for bundles of components. Redefine the builtins, or create your own.
---@field template_dirs string[] List of other directories to search for task templates.
---@field template_timeout_ms? integer For template providers, how long to wait (in ms) before timing out. Set to 0 to disable timeouts.
---@field template_cache_threshold_ms? integer Cache template provider results if the provider takes longer than this to run. Time is in ms. Set to 0 to disable caching.

---@class (exact) overseer.SetupOpts
---@field dap? boolean Patch nvim-dap to support preLaunchTask and postDebugTask
---@field log_level? integer Log level
---@field wrap_builtins? overseer.SetupConfigWrapBuiltins
---@field task_list? overseer.SetupConfigTaskList
---@field actions? table<string, false|overseer.Action> See :help overseer-actions
---@field form? overseer.SetupConfigFloatWin
---@field task_win? overseer.SetupConfigTaskWin
---@field component_aliases? table<string, overseer.Serialized[]> Aliases for bundles of components. Redefine the builtins, or create your own.
---@field template_dirs? string[] List of other directories to search for task templates.
---@field template_timeout_ms? integer For template providers, how long to wait (in ms) before timing out. Set to 0 to disable timeouts.
---@field template_cache_threshold_ms? integer Cache template provider results if the provider takes longer than this to run. Time is in ms. Set to 0 to disable caching.

---@class (exact) overseer.ConfigWrapBuiltins
---@field enabled boolean overseer will hook vim.system and vim.fn.jobstart and display those as tasks
---@field condition fun(cmd: string|string[], caller: overseer.Caller, opts?: table): boolean callback to determine if overseer should create a task for this jobstart/system

---@class (exact) overseer.SetupConfigWrapBuiltins
---@field enabled? boolean overseer will hook vim.system and vim.fn.jobstart and display those as tasks
---@field condition? fun(cmd: string|string[], caller: overseer.Caller, opts?: table): boolean callback to determine if overseer should create a task for this jobstart/system

---@class (exact) overseer.ConfigTaskList : overseer.LayoutOpts
---@field direction "left"|"right"|"bottom"
---@field separator string String that separates tasks
---@field child_indent {[1]: string, [2]: string, [3]: string}
---@field render fun(task: overseer.Task): string[][] Function that renders tasks
---@field sort fun(a: overseer.Task, b: overseer.Task): boolean Function that sorts tasks
---@field keymaps table<string, any> Set keymap to false to remove default behavior

---@class (exact) overseer.SetupConfigTaskList
---@field direction? "left"|"right"|"bottom" Direction to open task list (default "bottom")
---@field max_width? number|number[] Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%). min_width and max_width can be a single value or a list of mixed integer/float types. max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
---@field min_width? number|number[] min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
---@field max_height? number|number[]
---@field min_height? number|number[]
---@field separator? string String that separates tasks
---@field child_indent? {[1]: string, [2]: string, [3]: string}
---@field render? fun(task: overseer.Task): string[] Function that renders tasks
---@field sort? fun(a: overseer.Task, b: overseer.Task): boolean Function that sorts tasks
---@field keymaps? table<string, any> Set keymap to false to remove default behavior

---@class (exact) overseer.ConfigFloatWin : overseer.LayoutOpts
---@field zindex integer
---@field win_opts table<string, any>

---@class (exact) overseer.SetupConfigFloatWin
---@field zindex? integer
---@field min_width? number|number[]
---@field max_width? number|number[]
---@field min_height? number|number[]
---@field max_height? number|number[]
---@field win_opts? table<string, any>

---@class (exact) overseer.ConfigTaskWin
---@field padding integer
---@field zindex? integer
---@field win_opts table<string, any>

---@class (exact) overseer.SetupConfigTaskWin
---@field padding? integer How much space to leave around the floating window
---@field zindex? integer
---@field win_opts? table<string, any> Set any window options here (e.g. winhighlight)

setmetatable(M, {
  -- If the user hasn't called setup() yet, make sure we correctly set up the config object so there
  -- aren't random crashes.
  __index = function(self, key)
    if not has_setup then
      M.setup()
    end
    return rawget(self, key)
  end,
})

---@cast M overseer.Config
return M
