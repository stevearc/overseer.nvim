local parser = require("overseer.parser")
local util = require("overseer.util")
local Test = {}

function Test.new(opts, pattern)
  if not pattern then
    pattern = opts
    opts = {}
  end
  return setmetatable({
    regex = opts.regex,
    pattern = pattern,
  }, { __index = Test })
end

function Test:reset() end

function Test:ingest(line)
  for _, pattern in util.iter_as_list(self.pattern) do
    if type(pattern) == "string" then
      if self.regex then
        if vim.fn.match(line, pattern) >= 0 then
          return parser.STATUS.SUCCESS
        end
      elseif line:match(pattern) then
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

return Test
