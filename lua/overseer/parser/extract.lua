local parser = require("overseer.parser")

local Extract = {
  desc = "Parse a line into an object and append it to the results",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
        {
          name = "consume",
          type = "boolean",
          desc = "Consumes the line of input, blocking execution until the next line is fed in",
          default = true,
        },
        {
          name = "append",
          type = "boolean",
          desc = "After parsing, append the item to the results list. When false, the pending item will stick around.",
          default = true,
        },
        {
          name = "regex",
          type = "boolean",
          desc = "Use vim regex instead of lua pattern (see :help pattern)",
          default = false,
        },
        {
          name = "postprocess",
          type = "function",
          desc = "Call this function to do post-extraction processing on the values",
        },
      },
    },
    {
      name = "pattern",
      type = "string|function|string[]",
      desc = "The lua pattern to use for matching. Must have the same number of capture groups as there are field arguments.",
      long_desc = "Can also be a list of strings/functions and it will try matching against all of them",
    },
    {
      name = "field",
      type = "string",
      vararg = true,
      desc = 'The name of the extracted capture group. Use `"_"` to discard.',
    },
  },
  examples = {
    {
      desc = [[Convert a line in the format of `/path/to/file.txt:123: This is a message` into an item `{filename = "/path/to/file.txt", lnum = 123, text = "This is a message"}`]],
      code = [[{"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }]],
    },
    {
      desc = [[The same logic, but using a vim regex]],
      code = [[{"extract", {regex = true}, "\\v^([^:space:].+):(\\d+): (.+)$", "filename", "lnum", "text" }]],
    },
  },
}

function Extract.new(opts, pattern, ...)
  local fields
  if type(opts) ~= "table" then
    fields = { pattern, ... }
    pattern = opts
    opts = {}
  else
    fields = { ... }
  end
  opts = vim.tbl_deep_extend("keep", opts, {
    consume = true,
    append = true,
    regex = false,
  })
  return setmetatable({
    consume = opts.consume,
    append = opts.append,
    postprocess = opts.postprocess,
    done = nil,
    pattern = pattern,
    extract = parser.util.patterns_to_extract(pattern, opts.regex, fields),
  }, { __index = Extract })
end

function Extract:reset()
  self.done = nil
end

function Extract:ingest(line, ctx)
  if self.done then
    return self.done
  end

  local item = self.extract(line)
  if item then
    for k, v in pairs(item) do
      ctx.item[k] = v
    end
    vim.tbl_extend("force", ctx.item, item)
  end

  if not item then
    self.done = parser.STATUS.FAILURE
    return parser.STATUS.FAILURE
  end
  if self.postprocess then
    self.postprocess(ctx.item, ctx)
  end
  parser.util.append_item(self.append, line, ctx)
  self.done = parser.STATUS.SUCCESS
  return self.consume and parser.STATUS.RUNNING or parser.STATUS.SUCCESS
end

return Extract
