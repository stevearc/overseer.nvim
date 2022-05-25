local default_config = {
  list_sep = "────────────────────────────────────────",
  use_builtin_templates = true,
  sidebar = {
    max_width = { 100, 0.2 },
    min_width = { 40, 0.1 },
  },
  actions = {},
  form = {
    border = "rounded",
    min_width = 80,
    max_width = 0.9,
    min_height = 10,
    max_height = 0.9,
    winblend = 10,
  },
  component_sets = {
    default = {
      "output_summary",
      "exit_code",
      "notify_result",
      "rerun_trigger",
      "dispose_delay",
    },
    default_test = {
      "default",
      "diagnostic_result",
      "quickfix_stacktrace",
    },
    default_persist = {
      "output_summary",
      "exit_code",
      "notify_result",
      "rerun_trigger",
      "rerun_on_result",
    },
  },
}

local M = vim.deepcopy(default_config)

M.setup = function(opts)
  opts = opts or {}
  local newconf = vim.tbl_deep_extend("force", default_config, opts)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  -- Merge actions with actions.lua
  local actions = {}
  for k, v in pairs(require("overseer.actions")) do
    actions[k] = v
  end
  for k, v in pairs(opts.actions or {}) do
    if not v then
      actions[k] = nil
    else
      actions[k] = v
    end
  end
  M.actions = actions

  if M.use_builtin_templates then
    require("overseer.template").register_builtin()
  end

  local component = require("overseer.component")
  for k, v in pairs(M.component_sets) do
    component.alias(k, v)
  end
end

return M
