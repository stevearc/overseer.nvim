local M = {}

local json_decode = vim.json.decode

---@param string string
---@param idx number
---@return string
---@return number?
local function get_to_line_end(string, idx)
  local newline = string:find("\n", idx, true)
  local to_end = newline and string:sub(idx, newline - 1) or string:sub(idx)
  return to_end, newline
end

---Splice out an inclusive range from a string
---@param string string
---@param start_idx number
---@param end_idx? number
---@return string
local function str_splice(string, start_idx, end_idx)
  local new_content = string:sub(1, start_idx - 1)
  if end_idx then
    return new_content .. string:sub(end_idx + 1)
  else
    return new_content
  end
end

---@param string string
---@param idx number
---@param needle string
---@return number?
local function str_rfind(string, idx, needle)
  for i = idx, 1, -1 do
    if string:sub(i, i - 1 + needle:len()) == needle then
      return i
    end
  end
end

---Decodes a json string that may contain comments or trailing commas
---@param content string
---@param opts? table
---@return any
M.decode = function(content, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    luanil = {
      object = true,
    },
  })
  local ok, data = pcall(json_decode, content, opts)
  while not ok do
    local err = assert(data)
    local char = err:match("invalid token at character (%d+)$")
    if char then
      local to_end, newline = get_to_line_end(content, char)
      if to_end:match("^//") then
        content = str_splice(content, char, newline)
        goto continue
      end
    end

    char = err:match("Expected object key string but found [^%s]+ at character (%d+)$")
    char = char or err:match("Expected value but found T_ARR_END at character (%d+)")
    if char then
      local comma_idx = str_rfind(content, char, ",")
      if comma_idx then
        content = str_splice(content, comma_idx, comma_idx)
        goto continue
      end
    end

    error(err)
    ::continue::
    ok, data = pcall(json_decode, content, opts)
  end
  return data
end

return M
