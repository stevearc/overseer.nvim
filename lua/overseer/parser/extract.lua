local parser = require("overseer.parser")
local util = require("overseer.util")

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
      type = "string|function",
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
    fields = util.pack(pattern, ...)
    pattern = opts
    opts = {}
  else
    fields = util.pack(...)
  end
  opts = vim.tbl_deep_extend("keep", opts, {
    consume = true,
    append = true,
    regex = false,
  })
  return setmetatable({
    consume = opts.consume,
    append = opts.append,
    regex = opts.regex,
    postprocess = opts.postprocess,
    done = nil,
    pattern = pattern,
    fields = fields,
  }, { __index = Extract })
end

function Extract:reset()
  self.done = nil
end

local function default_postprocess_field(value, _)
  if value:match("^%d+$") then
    return tonumber(value)
  end
  return value
end

function Extract:ingest(line, ctx)
  if self.done then
    return self.done
  end
  local item = ctx.item

  local any_match = false
  for _, pattern in util.iter_as_list(self.pattern) do
    local result
    if type(pattern) == "string" then
      if self.regex then
        result = vim.fn.matchlist(line, pattern)
        table.remove(result, 1)
      else
        result = util.pack(line:match(pattern))
      end
    else
      result = util.pack(pattern(line))
    end
    for i, field in ipairs(self.fields) do
      if result[i] then
        any_match = true
        local key, postprocess
        if type(field) == "table" then
          key, postprocess = unpack(field)
        else
          key = field
          postprocess = default_postprocess_field
        end
        if key ~= "_" then
          item[key] = postprocess(result[i], { item = item, field = key })
        end
      end
    end
    if any_match then
      break
    end
  end

  if not any_match then
    self.done = parser.STATUS.FAILURE
    return parser.STATUS.FAILURE
  end
  if self.postprocess then
    self.postprocess(item, ctx)
  end
  parser.util.append_item(self.append, line, ctx)
  self.done = parser.STATUS.SUCCESS
  return self.consume and parser.STATUS.RUNNING or parser.STATUS.SUCCESS
end

return Extract
