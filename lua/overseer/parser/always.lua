local parser = require("overseer.parser")
local util = require("overseer.parser.util")
local Always = {}

function Always.new(succeed, child)
  if child == nil then
    child = succeed
    succeed = true
  end
  return setmetatable({
    child = util.hydrate(child),
    succeed = succeed,
  }, { __index = Always })
end

function Always:reset()
  self.child:reset()
end

function Always:ingest(...)
  local st = self.child:ingest(...)
  if st == parser.STATUS.RUNNING then
    return st
  end
  return self.succeed and parser.STATUS.SUCCESS or parser.STATUS.FAILURE
end

return Always
