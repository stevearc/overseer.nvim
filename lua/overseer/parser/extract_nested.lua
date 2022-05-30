local parser = require("overseer.parser")
local ExtractNested = {}

function ExtractNested.new(opts, name, child)
  if child == nil then
    child = name
    name = opts
    opts = {}
  end
  opts = vim.tbl_deep_extend("keep", opts, {
    append = true,
    fail_on_empty = true,
  })
  return setmetatable({
    child = child,
    name = name,
    append = opts.append,
    fail_on_empty = opts.fail_on_empty,
    results = {},
    item = {},
  }, { __index = ExtractNested })
end

function ExtractNested:reset()
  self.done = nil
end

function ExtractNested:ingest(line, ctx)
  if self.done then
    return self.done
  end
  local nested_ctx = {
    results = self.results,
    item = self.item,
  }
  local st = self.child:ingest(line, nested_ctx)
  if st == parser.STATUS.FAILURE then
    if not self.fail_on_empty or not vim.tbl_isempty(self.results) then
      st = parser.STATUS.SUCCESS
    end
  elseif st == parser.STATUS.RUNNING then
    return st
  end

  if st == parser.STATUS.SUCCESS then
    ctx.item[self.name] = self.results
    parser.util.append_item(self.append, line, ctx)
  end

  self.done = st
  return self.done
end
return ExtractNested.new
