local M = {}

M.get_cmd = function(defn)
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
    return string.format("%s %s", defn.command, table.concat(args, " "))
  else
    return defn.command
  end
end

return M
