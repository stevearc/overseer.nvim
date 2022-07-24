local M = {}

M.get_task_opts = function(defn)
  local cmd = defn.args or {}
  table.insert(cmd, 1, defn.command)
  return {
    cmd = cmd,
  }
end

return M
