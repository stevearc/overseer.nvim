local parser = require("overseer.parser")
local Append = {}

function Append.new()
  return setmetatable({}, { __index = Append })
end

function Append:reset() end

function Append:ingest(line, item, results)
  table.insert(results, vim.deepcopy(item))
  for k in pairs(item) do
    item[k] = nil
  end
  return parser.STATUS.SUCCESS
end

return Append.new
