local shell = require("overseer.shell")
local M = {}

M.get_task_opts = function(defn)
  local command = defn.command
  -- Only perform escaping if args is not empty
  if defn.args and not vim.tbl_isempty(defn.args) then
    local cmd_list = vim.list_extend({ defn.command }, defn.args)
    command = shell.escape_cmd(cmd_list)
  end
  return {
    cmd = command,
  }
end

return M
