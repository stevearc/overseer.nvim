local M = {}

M.get_task_opts = function(defn)
  local ret = {}
  local args = {}
  for _, arg in ipairs(defn.args or {}) do
    if type(arg) == "string" then
      table.insert(args, vim.fn.shellescape(arg))
    else
      -- TODO we are ignoring the quoting option for now
      table.insert(args, vim.fn.shellescape(arg.value))
    end
  end
  if #args > 0 then
    ret.cmd = string.format("%s %s", defn.command, table.concat(args, " "))
  else
    ret.cmd = defn.command
  end
  return ret
end

return M
