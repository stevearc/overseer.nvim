local parser = require("overseer.parser")
local util = require("overseer.util")
local SkipUntil = {}

function SkipUntil.new(opts, ...)
  local patterns
  if type(opts) ~= "table" then
    patterns = util.pack(opts, ...)
    opts = {}
  else
    patterns = util.pack(...)
  end
  vim.validate({
    skip_matching_line = { opts.skip_matching_line, "b", true },
  })
  if opts.skip_matching_line == nil then
    opts.skip_matching_line = true
  end
  return setmetatable({
    skip_matching_line = opts.skip_matching_line,
    patterns = patterns,
    done = false,
  }, { __index = SkipUntil })
end

function SkipUntil:reset()
  self.done = false
end

function SkipUntil:ingest(line)
  if self.done then
    return parser.STATUS.SUCCESS
  end
  for _, pattern in ipairs(self.patterns) do
    if line:match(pattern) then
      self.done = true
      if self.skip_matching_line then
        return parser.STATUS.RUNNING
      else
        return parser.STATUS.SUCCESS
      end
    end
  end
  return parser.STATUS.RUNNING
end

return SkipUntil
