local parser = require("overseer.parser")
local SkipUntil = {
  desc = "Skip over lines until one matches",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
        {
          name = "skip_matching_line",
          type = "boolean",
          desc = "Consumes the line that matches. Later nodes will only see the next line.",
          default = true,
        },
        {
          name = "regex",
          type = "boolean",
          desc = "Use vim regex instead of lua pattern (see :help pattern)",
          default = true,
        },
      },
    },
    {
      name = "pattern",
      vararg = true,
      type = "string|string[]|fun(line: string): string",
      desc = "The lua pattern to use for matching. The node succeeds if any of these patterns match.",
    },
  },
  examples = {
    {
      desc = [[Skip input until we see "Error" or "Warning"]],
      code = [[{"skip_until", "^Error:", "^Warning:"}]],
    },
  },
}

function SkipUntil.new(opts, ...)
  local patterns
  if type(opts) ~= "table" then
    patterns = { opts, ... }
    opts = {}
  else
    patterns = { ... }
  end
  vim.validate("skip_matching_line", opts.skip_matching_line, "boolean", true)
  if opts.skip_matching_line == nil then
    opts.skip_matching_line = true
  end
  return setmetatable({
    skip_matching_line = opts.skip_matching_line,
    test = parser.util.patterns_to_test(patterns, opts.regex),
    done = false,
  }, { __index = SkipUntil })
end

function SkipUntil:reset()
  self.done = false
end

function SkipUntil:ingest(line)
  if self.done then
    return parser.STATUS.SUCCESS
  end
  if self.test(line) then
    self.done = true
    if self.skip_matching_line then
      return parser.STATUS.RUNNING
    else
      return parser.STATUS.SUCCESS
    end
  end
  return parser.STATUS.RUNNING
end

return SkipUntil
