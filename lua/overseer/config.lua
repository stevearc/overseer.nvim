local default_config = {
  list_sep = "────────────────────────────────────────",
  extensions = { "builtin" },
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
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "on_rerun_handler",
      "dispose_delay",
    },
    default_test = {
      "default",
      "on_result_diagnostics",
      "on_result_stacktrace_quickfix",
    },
    default_persist = {
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "on_rerun_handler",
      "rerun_on_result",
    },
  },
}

local M = vim.deepcopy(default_config)

M.setup = function(opts)
  local component = require("overseer.component")
  local extensions = require("overseer.extensions")
  local util = require("overseer.util")
  opts = opts or {}
  local newconf = vim.tbl_deep_extend("force", default_config, opts)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  -- Merge actions with actions.lua
  local actions = {}
  for k, v in pairs(require("overseer.actions").actions) do
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

  for _, v in util.iter_as_list(M.extensions) do
    extensions.register(v)
  end

  component.register_builtin()
  for k, v in pairs(M.component_sets) do
    component.alias(k, v)
  end
end

return M
