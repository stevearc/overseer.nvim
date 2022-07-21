local parser = require("overseer.parser")
local util = require("overseer.parser.util")
local Invert = {
  desc = "A decorator that inverts the child's return value",
  doc_args = {
    {
      name = "child",
      type = "parser",
      desc = "The child parser node",
    },
  },
  examples = {
    {
      desc = [[An extract node that returns SUCCESS when it fails, and vice-versa]],
      code = [[
  {"invert",
    {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
  }
]],
    },
  },
}

function Invert.new(child)
  return setmetatable({
    child = util.hydrate(child),
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

return Invert
