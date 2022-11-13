local parser = require("overseer.parser")
local Test = {
  desc = "Returns SUCCESS when the line matches the pattern",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
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
      type = "string|fun(line: string): string",
      desc = "The lua pattern to use for matching, or test function",
    },
  },
  examples = {
    {
      desc = [[Fail until a line starts with "panic:"]],
      code = [[{"test", "^panic:"}]],
    },
  },
}

function Test.new(opts, pattern)
  if not pattern then
    pattern = opts
    opts = {}
  end
  return setmetatable({
    test = parser.util.patterns_to_test(pattern, opts.regex),
  }, { __index = Test })
end

function Test:reset() end

function Test:ingest(line)
  if self.test(line) then
    return parser.STATUS.SUCCESS
  else
    return parser.STATUS.FAILURE
  end
end

return Test
