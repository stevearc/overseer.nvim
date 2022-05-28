local parser = require("overseer.parser")
local Loop = {}

local MAX_LOOP = 10

function Loop.new(opts, child)
  if child == nil then
    child = opts
    opts = {}
  end
  vim.validate({
    ignore_failure = { opts.ignore_failure, "b", true },
    repetitions = { opts.repetitions, "n", true },
  })
  return setmetatable({
    ignore_failure = opts.ignore_failure,
    repetitions = opts.repetitions,
    count = 0,
    child = child,
  }, { __index = Loop })
end

function Loop:reset()
  self.count = 0
  self.child:reset()
end

function Loop:ingest(...)
  local loop_count = 0
  local st
  repeat
    if self.repetitions and self.count >= self.repetitions then
      return parser.STATUS.SUCCESS
    end
    st = self.child:ingest(...)
    if st == parser.STATUS.SUCCESS then
      self.child:reset()
      self.count = self.count + 1
    elseif st == parser.STATUS.FAILURE then
      self.child:reset()
      self.count = self.count + 1
      if not self.ignore_failure then
        return st
      end
    end
    loop_count = loop_count + 1
  until st == parser.STATUS.RUNNING or loop_count >= MAX_LOOP
  -- TODO log warning if loop_count >= MAX_LOOP
  return parser.STATUS.RUNNING
end

return Loop.new
