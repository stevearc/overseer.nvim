local parser = require("overseer.parser")
local util = require("overseer.parser.util")
local Always = {
  desc = "A decorator that always returns SUCCESS",
  doc_args = {
    {
      name = "succeed",
      type = "boolean",
      desc = "Set to false to always return FAILURE",
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
      desc = [[An extract node that returns SUCCESS even when it fails]],
      code = [[
  {"always",
    {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
  }
]],
    },
  },
}

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
