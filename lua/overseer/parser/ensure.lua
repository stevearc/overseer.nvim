local parser = require("overseer.parser")
local util = require("overseer.parser.util")
local Ensure = {
  desc = "Decorator that runs a child until it succeeds",
  doc_args = {
    {
      name = "succeed",
      type = "boolean",
      desc = "Set to false to run child until failure",
      default = true,
      position_optional = true,
    },
    {
      name = "child",
      type = "parser",
      desc = "The child parser node",
    },
  },
  examples = {
    {
      desc = [[An extract node that runs until it successfully parses]],
      code = [[
  {"ensure",
    {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
  }
]],
    },
  },
}

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

return Ensure
