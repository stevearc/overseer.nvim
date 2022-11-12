local parser = require("overseer.parser")
local Dispatch = {
  desc = "Dispatch an event",
  doc_args = {
    {
      name = "name",
      type = "string",
      desc = "Event name",
    },
    {
      name = "arg",
      type = "any|fun()",
      desc = "A value to send with the event, or a function that creates a value",
      vararg = true,
    },
  },
  examples = {
    {
      desc = [[Dispatch an "output_start" event]],
      code = [[{"dispatch", "output_start"}]],
    },
  },
}

function Dispatch.new(name, ...)
  return setmetatable({
    name = name,
    args = { ... },
  }, { __index = Dispatch })
end

function Dispatch:reset() end

function Dispatch:ingest(line, ctx)
  local params = {}
  for _, v in ipairs(self.args) do
    if type(v) == "function" then
      table.insert(params, v(line, ctx))
    else
      table.insert(params, v)
    end
  end
  ctx.dispatch(self.name, unpack(params))
  return parser.STATUS.SUCCESS
end

return Dispatch
