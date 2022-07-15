local parser = require("overseer.parser")
local util = require("overseer.parser.util")
local Ensure = {}

local MAX_LOOP = 2

function Ensure.new(succeed, child)
  if type(succeed) ~= "boolean" then
    child = succeed
    succeed = true
  end
  return setmetatable({
    child = util.hydrate(child),
    succeed = succeed,
  }, { __index = Ensure })
end

function Ensure:reset()
  self.child:reset()
end

function Ensure:ingest(...)
  for _ = 1, MAX_LOOP do
    local st = self.child:ingest(...)
    if st == parser.STATUS.FAILURE and self.succeed then
      self.child:reset()
    elseif st == parser.STATUS.SUCCESS and not self.succeed then
      self.child:reset()
    else
      return st
    end
  end
  return parser.STATUS.RUNNING
end

return Ensure.new
