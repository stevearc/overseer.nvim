local default_config = {
  list_sep = "────────────────────────────────────────",
  use_builtin_templates = true,
  component_sets = {
    default = {
      "output_summary",
      "exit_code",
      "notify_result",
      "rerun_trigger",
      "dispose_delay",
    },
    default_once = {
      "output_summary",
      "exit_code",
      "notify_result",
      "dispose_delay",
    },
    default_persist = {
      "output_summary",
      "exit_code",
      "notify_result",
      "rerun_trigger",
      "rerun_on_result",
    },
    default_watch = {
      "output_summary",
      "exit_code",
      { "notify_result", statuses = { require("overseer.constants").STATUS.FAILURE } },
      { "rerun_trigger", interrupt = true },
      "rerun_on_save",
    },
  },
}

local M = vim.deepcopy(default_config)

M.setup = function(opts)
  local newconf = vim.tbl_deep_extend("force", default_config, opts or {})
  for k, v in pairs(newconf) do
    M[k] = v
  end

  if M.use_builtin_templates then
    require("overseer.template").register_all()
  end

  local component = require("overseer.component")
  for k, v in pairs(M.component_sets) do
    component.alias(k, v)
  end
end

return M
