local parser = require("overseer.parser")
local parser_util = require("overseer.parser.util")
local Sequence = {
  desc = "Run the child nodes sequentially",
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
      },
    },
    {
      name = "child",
      type = "parser",
      vararg = true,
      desc = "The child parser nodes. Can be passed in as varargs or as a list.",
    },
  },
  examples = {
    {
      desc = [[Extract the message text from one line, then the filename and lnum from the next line]],
      code = [[
      {"sequence",
        {"extract", { append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"},
        {"extract", "^%s+([^:]+.go):([0-9]+)", "filename", "lnum"}
      }
      ]],
    },
  },
}

function Sequence.new(opts, ...)
  local children
  if parser_util.is_parser(opts) then
    -- No opts, children passed in as args
    children = vim.F.pack_len(opts, ...)
    opts = {}
  elseif parser_util.tbl_is_parser_list(opts) then
    -- No opts, children are passed in as a list
    children = opts
    opts = {}
  else
    if select("#", ...) == 1 then
      local arg1 = select(1, ...)
      -- we got opts, and children are passed in as a list
      if parser_util.tbl_is_parser_list(arg1) then
        children = arg1
      end
    end
    if not children then
      -- children are passed in as args
      children = vim.F.pack_len(...)
    end
  end
  vim.validate({
    break_on_first_failure = { opts.break_on_first_failure, "b", true },
    break_on_first_success = { opts.break_on_first_success, "b", true },
  })
  opts = vim.tbl_deep_extend("keep", opts, {
    break_on_first_failure = true,
    break_on_first_success = false,
  })
  return setmetatable({
    idx = 1,
    any_failures = false,
    break_on_first_success = opts.break_on_first_success,
    break_on_first_failure = opts.break_on_first_failure,
    children = parser_util.hydrate_list(children),
  }, { __index = Sequence })
end

function Sequence:reset()
  self.idx = 1
  self.any_failures = false
  for _, child in ipairs(self.children) do
    child:reset()
  end
end

function Sequence:ingest(...)
  while self.idx <= #self.children do
    local child = self.children[self.idx]
    local st = child:ingest(...)
    if st == parser.STATUS.SUCCESS then
      if self.break_on_first_success then
        return st
      end
    elseif st == parser.STATUS.FAILURE then
      self.any_failures = true
      if self.break_on_first_failure then
        return st
      end
    elseif st == parser.STATUS.RUNNING then
      return st
    end
    self.idx = self.idx + 1
  end

  if self.any_failures then
    return parser.STATUS.FAILURE
  else
    return parser.STATUS.SUCCESS
  end
end

return Sequence
