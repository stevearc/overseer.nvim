local parser = require("overseer.parser")
local util = require("overseer.util")
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
      type = "string",
      desc = "The lua pattern to use for matching",
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
    regex = opts.regex,
    pattern = pattern,
  }, { __index = Test })
end

function Test:reset() end

function Test:ingest(line)
  for _, pattern in util.iter_as_list(self.pattern) do
    if type(pattern) == "string" then
      if self.regex then
        if vim.fn.match(line, pattern) >= 0 then
          return parser.STATUS.SUCCESS
        end
      elseif line:match(pattern) then
        return parser.STATUS.SUCCESS
      end
    else
      if pattern(line) then
        return parser.STATUS.SUCCESS
      end
    end
  end

  return parser.STATUS.FAILURE
end

return Test
