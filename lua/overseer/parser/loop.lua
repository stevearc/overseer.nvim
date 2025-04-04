local parser = require("overseer.parser")
local util = require("overseer.parser.util")
local Loop = {
  desc = "A decorator that repeats the child",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
        {
          name = "ignore_failure",
          type = "boolean",
          desc = "Keep looping even when the child fails",
          default = false,
        },
        {
          name = "repetitions",
          type = "integer",
          desc = "When set, loop a set number of times then return SUCCESS",
        },
      },
    },
    {
      name = "child",
      type = "parser",
      desc = "The child parser node",
    },
  },
}

local MAX_LOOP = 2

function Loop.new(opts, child)
  if child == nil then
    child = opts
    opts = {}
  end
  vim.validate("ignore_failure", opts.ignore_failure, "boolean", true)
  vim.validate("repetitions", opts.repetitions, "number", true)
  return setmetatable({
    ignore_failure = opts.ignore_failure,
    repetitions = opts.repetitions,
    count = 0,
    done = nil,
    child = util.hydrate(child),
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
    end
    loop_count = loop_count + 1
  until st == parser.STATUS.RUNNING or loop_count >= MAX_LOOP
  return parser.STATUS.RUNNING
end

return Loop
