local util = require("overseer.util")
local M = {}

M.append_item = function(append, line, ctx)
  if not append then
    return
  end
  local item = vim.tbl_deep_extend("keep", ctx.item, ctx.default_values or {})
  if type(append) == "function" then
    append(ctx.results, vim.deepcopy(item), { line = line })
  else
    table.insert(ctx.results, vim.deepcopy(item))
  end

  for k in pairs(ctx.item) do
    ctx.item[k] = nil
  end
end

---@param data table|nil A parser or parser definition
M.hydrate = function(data)
  vim.validate({
    data = { data, "t", true },
  })
  if not data then
    return nil
  end
  if data.ingest then
    return data
  else
    local constructor = require("overseer.parser")[data[1]]
    local args = util.tbl_slice(data, 2)
    return constructor(unpack(args))
  end
end

---@param list table[]
M.hydrate_list = function(list)
  vim.validate({
    list = { list, "t" },
  })
  local ret = {}
  for _, v in ipairs(list) do
    table.insert(ret, M.hydrate(v))
  end
  return ret
end

---@param data table
---@return boolean
M.is_parser = function(data)
  if type(data) ~= "table" then
    return false
  end
  return data.ingest or (vim.tbl_islist(data) and type(data[1]) == "string")
end

---@param list any
---@return boolean
M.tbl_is_parser_list = function(list)
  if not vim.tbl_islist(list) then
    return false
  end
  return util.list_all(list, M.is_parser)
end

return M
