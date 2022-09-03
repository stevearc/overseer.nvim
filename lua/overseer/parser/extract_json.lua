local parser = require("overseer.parser")
local ExtractJson = {
  desc = "Parse a line as json and append it to the results",
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
          name = "test",
          type = "function",
          desc = "A function that operates on the parsed value and returns true/false for SUCCESS/FAILURE",
        },
        {
          name = "postprocess",
          type = "function",
          desc = "Call this function to do post-extraction processing on the values",
        },
      },
    },
  },
}

function ExtractJson.new(opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("keep", opts, {
    append = true,
    consume = true,
  })
  return setmetatable({
    append = opts.append,
    consume = opts.consume,
    test = opts.test,
    postprocess = opts.postprocess,
    done = nil,
  }, { __index = ExtractJson })
end

function ExtractJson:reset()
  self.done = nil
end

function ExtractJson:ingest(line, ctx)
  if self.done then
    return self.done
  end
  local item = ctx.item

  local ok, result = pcall(vim.json.decode, line, { luanil = { object = true } })
  if not ok or (self.test and not self.test(result)) then
    self.done = parser.STATUS.FAILURE
    return parser.STATUS.FAILURE
  end

  for k, v in pairs(result) do
    item[k] = v
  end

  if self.postprocess then
    self.postprocess(item, { line = line })
  end
  parser.util.append_item(self.append, line, ctx)
  self.done = parser.STATUS.SUCCESS
  return self.consume and parser.STATUS.RUNNING or parser.STATUS.SUCCESS
end

return ExtractJson
