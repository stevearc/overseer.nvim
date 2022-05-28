local parser = require("overseer.parser")
local Append = {}

function Append.new()
  return setmetatable({}, { __index = Append })
end

function Append:reset() end

function Append:ingest(line, ctx)
  table.insert(ctx.results, vim.deepcopy(ctx.item))
  for k in pairs(ctx.item) do
    ctx.item[k] = nil
  end
  return parser.STATUS.SUCCESS
end

return Append.new
