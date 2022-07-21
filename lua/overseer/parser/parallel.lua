local parser = require("overseer.parser")
local util = require("overseer.util")
local parser_util = require("overseer.parser.util")
local Parallel = {}

function Parallel.new(opts, ...)
  local children
  if parser_util.is_parser(opts) then
    children = util.pack(opts, ...)
    opts = {}
  else
    children = util.pack(...)
  end
  vim.validate({
    break_on_first_failure = { opts.break_on_first_failure, "b", true },
    break_on_first_success = { opts.break_on_first_success, "b", true },
    restart_children = { opts.restart_children, "b", true },
  })
  opts = vim.tbl_deep_extend("keep", opts, {
    break_on_first_failure = true,
    break_on_first_success = false,
    restart_children = false,
  })
  return setmetatable({
    break_on_first_success = opts.break_on_first_success,
    break_on_first_failure = opts.break_on_first_failure,
    restart_children = opts.restart_children,
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
    if self.restart_children then
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
