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
  return data.ingest or (vim.islist(data) and type(data[1]) == "string")
end

---@param list any
---@return boolean
M.tbl_is_parser_list = function(list)
  if not vim.islist(list) then
    return false
  end
  return util.list_all(list, M.is_parser)
end

---@param pattern string|fun()
---@param regex boolean
---@return fun(line: string): boolean
M.pattern_to_test = function(pattern, regex)
  if type(pattern) == "string" then
    if regex then
      return function(line)
        return vim.fn.match(line, pattern) >= 0
      end
    else
      return function(line)
        return line:match(pattern)
      end
    end
  else
    return pattern
  end
end

---@param patterns string[]|fun()[]
---@param regex boolean
---@return fun(line: string): boolean
M.patterns_to_test = function(patterns, regex)
  if type(patterns) ~= "table" then
    return M.pattern_to_test(patterns, regex)
  end
  local tests = {}
  for _, pat in ipairs(patterns) do
    table.insert(tests, M.pattern_to_test(pat, regex))
  end

  return function(line)
    for _, test in ipairs(tests) do
      if test(line) then
        return true
      end
    end
    return false
  end
end

local function default_postprocess_field(value, opts)
  if value:match("^%d+$") then
    return tonumber(value)
  elseif opts.field == "type" then
    return value:upper():match("^%w")
  else
    return value
  end
end

---@param pattern string|fun(line: string)
---@param regex boolean
---@param fields string[]
---@return fun(line: string): nil|table
M.pattern_to_extract = function(pattern, regex, fields)
  local match
  if type(pattern) == "string" then
    if regex then
      match = function(line)
        local result = vim.fn.matchlist(line, pattern)
        table.remove(result, 1)
        return result
      end
    else
      match = function(line)
        return { line:match(pattern) }
      end
    end
  else
    match = function(line)
      return { pattern(line) }
    end
  end
  return function(line)
    local result = match(line)
    if not result then
      return nil
    end
    local item
    for i, field in ipairs(fields) do
      if result[i] then
        if not item then
          item = {}
        end
        local key, postprocess
        if type(field) == "table" then
          key, postprocess = unpack(field)
        else
          key = field
          postprocess = default_postprocess_field
        end
        if key ~= "_" then
          item[key] = postprocess(result[i], { item = item, field = key })
        end
      end
    end
    return item
  end
end

---@param patterns string[]|fun()[]
---@param regex boolean
---@param fields string[]
---@return fun(line: string): nil|table
M.patterns_to_extract = function(patterns, regex, fields)
  if type(patterns) ~= "table" then
    return M.pattern_to_extract(patterns, regex, fields)
  end

  local extractors = {}
  for _, pat in ipairs(patterns) do
    table.insert(extractors, M.pattern_to_extract(pat, regex, fields))
  end

  return function(line)
    for _, ext in ipairs(extractors) do
      local item = ext(line)
      if item then
        return item
      end
    end
  end
end

return M
