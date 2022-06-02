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
    done = nil,
    child = child,
  }, { __index = Loop })
end

function Loop:reset()
  self.count = 0
  self.done = nil
  self.child:reset()
end

function Loop:ingest(...)
  if self.done then
    return self.done
  end
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
        self.done = st
        return st
      end
      return parser.STATUS.RUNNING
    end
    loop_count = loop_count + 1
  until st == parser.STATUS.RUNNING or loop_count >= MAX_LOOP
  if loop_count >= MAX_LOOP then
    local line = select(1, ...)
    vim.api.nvim_err_writeln(string.format("Max loop count exceeded for line '%s'", line))
  end
  return parser.STATUS.RUNNING
end

return Loop.new
