local M = {}

M.get_cmd = function(defn)
  local cmd = defn.args or {}
  table.insert(cmd, 1, defn.command)
  return cmd
end

return M
