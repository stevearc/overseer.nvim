local parser = require("overseer.parser")
local Invert = {}

function Invert.new(child)
  return setmetatable({
    child = child,
  }, { __index = Invert })
end

function Invert:reset()
  self.child:reset()
end

function Invert:ingest(...)
  local st = self.child:ingest(...)
  if st == parser.STATUS.FAILURE then
    return parser.STATUS.SUCCESS
  elseif st == parser.STATUS.SUCCESS then
    return parser.STATUS.FAILURE
  else
    return st
  end
end

return Invert.new
