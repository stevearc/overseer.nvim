local default_config = {
  list_sep = "────────────────────────────────────────",
  extensions = { "builtin" },
  sidebar = {
    default_detail = 1,
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
  test_icons = {
    ["NONE"] = " ",
    ["RUNNING"] = " ",
    ["SUCCESS"] = " ",
    ["FAILURE"] = " ",
    ["SKIPPED"] = " ",
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
      "on_result_report_tests",
    },
    default_persist = {
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "on_rerun_handler",
      "rerun_on_result",
    },
  },
  testing = {
    actions = {},
    disable = nil,
    modify = nil,
    disable_builtin = false,
    dirs = {},
    sidebar = {
      max_width = { 100, 0.2 },
      min_width = { 40, 0.1 },
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
  local extensions = require("overseer.extensions")
  local util = require("overseer.util")
  opts = opts or {}
  local newconf = vim.tbl_deep_extend("force", default_config, opts)
  for k, v in pairs(newconf) do
    M[k] = v
  end

  M.actions = merge_actions(require("overseer.task_list.actions"), newconf.actions)

  for k, v in pairs(newconf.test_icons) do
    local hl_name = string.format("OverseerTest%s", k)
    vim.fn.sign_define(hl_name, {
      text = v,
      texthl = hl_name,
      linehl = "",
      numhl = "",
    })
  end

  local testing_dirs = {}
  for k, v in pairs(M.testing.dirs) do
    local fullpath = vim.fn.expand(k)
    testing_dirs[fullpath] = v
  end
  M.testing.dirs = testing_dirs
  M.testing.actions = merge_actions(require("overseer.testing.actions"), newconf.testing.actions)

  for _, v in util.iter_as_list(M.extensions) do
    extensions.register(v)
  end

  component.register_builtin()
  for k, v in pairs(M.component_sets) do
    component.alias(k, v)
  end
end

return M
