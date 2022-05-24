local parser = require("overseer.parser")
local util = require("overseer.util")
local Test = {}

function Test.new(pattern)
  return setmetatable({
    pattern = pattern,
  }, { __index = Test })
end

function Test:reset() end

function Test:ingest(line)
  for _, pattern in util.iter_as_list(self.pattern) do
    if type(pattern) == "string" then
      if line:match(pattern) then
        return parser.STATUS.SUCCESS
      end
    else
      if pattern(line) then
        return parser.STATUS.SUCCESS
      end
    end
  end

  return parser.STATUS.FAILURE
end

return Test.new
