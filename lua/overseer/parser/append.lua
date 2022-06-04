local parser = require("overseer.parser")
local Append = {}

function Append.new(opts)
  opts = opts or {}
  return setmetatable({
    postprocess = opts.postprocess,
  }, { __index = Append })
end

function Append:reset() end

function Append:ingest(line, ctx)
  if self.postprocess then
    self.postprocess(ctx.item, ctx)
  end
  parser.util.append_item(true, line, ctx)
  return parser.STATUS.SUCCESS
end

return Append.new
