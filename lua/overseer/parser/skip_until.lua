local parser = require("overseer.parser")
local util = require("overseer.util")
local SkipUntil = {}

function SkipUntil.new(...)
  return setmetatable({ patterns = util.pack(...) }, { __index = SkipUntil })
end

function SkipUntil:reset() end

function SkipUntil:ingest(line)
  for _, pattern in ipairs(self.patterns) do
    if line:match(pattern) then
      return parser.STATUS.SUCCESS
    end
  end
  return parser.STATUS.RUNNING
end

return SkipUntil.new
