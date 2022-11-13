local parser = require("overseer.parser")
local Dispatch = {
  desc = "Dispatch an event",
  long_desc = "Events can be subscribed to using the parser:subscribe() method.",
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
      desc = [[clear_results will clear all current results from the parser. Pass `true` to only clear the results under the current key]],
      code = [[{"dispatch", "clear_results"}]],
    },
    {
      desc = [[set_results is used by the on_output_parse component to immediately set the current results on the task]],
      code = [[{"dispatch", "set_results"}]],
    },
  },
}

function Dispatch.new(name, ...)
  return setmetatable({
    event_name = name,
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
  ctx.dispatch(self.event_name, unpack(params))
  return parser.STATUS.SUCCESS
end

return Dispatch
