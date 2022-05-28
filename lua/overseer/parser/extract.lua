local parser = require("overseer.parser")
local util = require("overseer.util")
local Extract = {}

function Extract.new(opts, pattern, ...)
  local fields
  if type(opts) ~= "table" then
    fields = util.pack(pattern, ...)
    pattern = opts
    opts = {}
  else
    fields = util.pack(...)
  end
  opts = vim.tbl_deep_extend("keep", opts, {
    consume = true,
    append = true,
    regex = false,
  })
  return setmetatable({
    consume = opts.consume,
    append = opts.append,
    regex = opts.regex,
    postprocess = opts.postprocess,
    done = nil,
    pattern = pattern,
    fields = fields,
  }, { __index = Extract })
end

function Extract:reset()
  self.done = nil
end

local function default_postprocess_field(value, _)
  if value:match("^%d+$") then
    return tonumber(value)
  end
  return value
end

function Extract:ingest(line, ctx)
  if self.done then
    return self.done
  end
  local item = ctx.item

  local any_match = false
  for _, pattern in util.iter_as_list(self.pattern) do
    local result
    if type(pattern) == "string" then
      if self.regex then
        result = vim.fn.matchlist(line, pattern)
        table.remove(result, 1)
      else
        result = util.pack(line:match(pattern))
      end
    else
      result = util.pack(pattern(line))
    end
    for i, field in ipairs(self.fields) do
      if result[i] then
        any_match = true
        local key, postprocess
        if type(field) == "table" then
          key, postprocess = unpack(field)
        else
          key = field
          postprocess = default_postprocess_field
        end
        item[key] = postprocess(result[i], { item = item, field = key })
      end
    end
    if any_match then
      break
    end
  end

  if not any_match then
    self.done = parser.STATUS.FAILURE
    return parser.STATUS.FAILURE
  end
  if self.postprocess then
    self.postprocess(item, { line = line })
  end
  parser.util.append_item(self.append, line, ctx)
  self.done = parser.STATUS.SUCCESS
  return self.consume and parser.STATUS.RUNNING or parser.STATUS.SUCCESS
end

return Extract.new
