local parser = require("overseer.parser")
local parser_util = require("overseer.parser.util")
local Parallel = {
  desc = "Run the child nodes in parallel",
  long_desc = "The children are still run in-order, it just means that the input lines are fed to all the children on every iteration",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
        {
          name = "break_on_first_failure",
          type = "boolean",
          desc = "Stop executing as soon as a child returns FAILURE",
          default = true,
        },
        {
          name = "break_on_first_success",
          type = "boolean",
          desc = "Stop executing as soon as a child returns SUCCESS",
          default = false,
        },
        {
          name = "reset_children",
          type = "boolean",
          desc = "Reset all children at the beginning of each iteration",
          default = false,
        },
      },
    },
    {
      name = "child",
      type = "parser",
      vararg = true,
      desc = "The child parser nodes. Can be passed in as varargs or as a list.",
    },
  },
}

function Parallel.new(opts, ...)
  local children
  if parser_util.is_parser(opts) then
    children = vim.F.pack_len(opts, ...)
    opts = {}
  else
    children = vim.F.pack_len(...)
  end
  vim.validate({
    break_on_first_failure = { opts.break_on_first_failure, "b", true },
    break_on_first_success = { opts.break_on_first_success, "b", true },
    reset_children = { opts.reset_children, "b", true },
  })
  opts = vim.tbl_deep_extend("keep", opts, {
    break_on_first_failure = true,
    break_on_first_success = false,
    reset_children = false,
  })
  return setmetatable({
    break_on_first_success = opts.break_on_first_success,
    break_on_first_failure = opts.break_on_first_failure,
    reset_children = opts.reset_children,
    children = parser_util.hydrate_list(children),
  }, { __index = Parallel })
end

function Parallel:reset()
  for _, child in ipairs(self.children) do
    child:reset()
  end
end

function Parallel:ingest(...)
  local any_failed = false
  local any_running = false
  for _, child in ipairs(self.children) do
    if self.reset_children then
      child:reset()
    end
    local st = child:ingest(...)
    if st == parser.STATUS.SUCCESS then
      if self.break_on_first_success then
        return st
      end
    elseif st == parser.STATUS.FAILURE then
      if self.break_on_first_failure then
        return st
      end
      any_failed = true
    else
      any_running = true
    end
  end

  if any_running then
    return parser.STATUS.RUNNING
  elseif any_failed then
    return parser.STATUS.FAILURE
  else
    return parser.STATUS.SUCCESS
  end
end

return Parallel
