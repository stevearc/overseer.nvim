local parser = require("overseer.parser")
local ExtractMultiline = {}

function ExtractMultiline.new(opts, pattern, field)
  if field == nil then
    field = pattern
    pattern = opts
    opts = {}
  end
  opts = vim.tbl_deep_extend("keep", opts, {
    append = true,
  })
  return setmetatable({
    append = opts.append,
    done = nil,
    any_match = false,
    pattern = pattern,
    field = field,
  }, { __index = ExtractMultiline })
end

function ExtractMultiline:reset()
  self.done = nil
  self.any_match = false
end

local function append_line(item, key, value)
  if not item[key] then
    item[key] = value
  else
    item[key] = item[key] .. "\n" .. value
  end
end

function ExtractMultiline:ingest(line, ctx)
  if self.done then
    return self.done
  end
  local item = ctx.item

  local result
  if type(self.pattern) == "string" then
    result = line:match(self.pattern)
  else
    result = self.pattern(line)
  end
  if result then
    self.any_match = true
    if type(self.field) == "table" then
      local key, postprocess = unpack(self.field)
      append_line(item, key, postprocess(result, self))
    else
      append_line(item, self.field, result)
    end
    return parser.STATUS.RUNNING
  else
    if self.any_match or not vim.tbl_isempty(item) then
      self.done = parser.STATUS.SUCCESS
      parser.util.append_item(self.append, line, ctx)
    else
      self.done = parser.STATUS.FAILURE
    end
    return self.done
  end
end

return ExtractMultiline.new
