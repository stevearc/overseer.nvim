local parser = require("overseer.parser")
local ExtractJson = {}

function ExtractJson.new(opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("keep", opts, {
    append = true,
    consume = true,
  })
  return setmetatable({
    append = opts.append,
    consume = opts.consume,
    test = opts.test,
    postprocess = opts.postprocess,
    done = nil,
  }, { __index = ExtractJson })
end

function ExtractJson:reset()
  self.done = nil
end

function ExtractJson:ingest(line, ctx)
  if self.done then
    return self.done
  end
  local item = ctx.item

  local ok, result = pcall(vim.json.decode, line)
  if not ok or (self.test and not self.test(result)) then
    self.done = parser.STATUS.FAILURE
    return parser.STATUS.FAILURE
  end

  for k, v in pairs(result) do
    item[k] = v
  end

  if self.postprocess then
    self.postprocess(item, { line = line })
  end
  parser.util.append_item(self.append, line, ctx)
  self.done = parser.STATUS.SUCCESS
  return self.consume and parser.STATUS.RUNNING or parser.STATUS.SUCCESS
end

return ExtractJson.new
