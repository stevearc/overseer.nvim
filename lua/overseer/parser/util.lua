local M = {}

M.append_item = function(append, line, ctx)
  if not append then
    return
  end
  local item = vim.tbl_deep_extend("keep", ctx.item, ctx.context or {})
  if type(append) == "function" then
    append(ctx.results, vim.deepcopy(item), { line = line })
  else
    table.insert(ctx.results, vim.deepcopy(item))
  end

  for k in pairs(ctx.item) do
    ctx.item[k] = nil
  end
end

return M
