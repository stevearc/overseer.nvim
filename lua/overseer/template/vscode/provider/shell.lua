local shell = require("overseer.shell")
local M = {}

M.get_task_opts = function(defn)
  local command = vim.list_extend({ defn.command }, defn.args or {})
  return {
    cmd = shell.escape_cmd(command),
  }
end

return M
