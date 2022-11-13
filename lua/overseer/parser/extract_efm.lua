local parser = require("overseer.parser")
local ExtractEfm = {
  desc = "Parse a line using vim's errorformat and append it to the results",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
        {
          name = "efm",
          type = "string",
          desc = "The errorformat string to use. Defaults to current option value.",
        },
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

function ExtractEfm.new(opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("keep", opts, {
    append = true,
    consume = true,
  })
  return setmetatable({
    efm = opts.efm,
    append = opts.append,
    consume = opts.consume,
    test = opts.test,
    postprocess = opts.postprocess,
    done = nil,
  }, { __index = ExtractEfm })
end

function ExtractEfm:reset()
  self.done = nil
end

function ExtractEfm:ingest(line, ctx)
  if self.done then
    return self.done
  end
  local item = ctx.item

  local parsed_item = vim.fn.getqflist({
    lines = { line },
    efm = self.efm,
  }).items[1]
  if not parsed_item or parsed_item.valid ~= 1 or (self.test and not self.test(parsed_item)) then
    self.done = parser.STATUS.FAILURE
    return parser.STATUS.FAILURE
  end

  -- Convert the quickfix item format to something a little easier to process
  if not parsed_item.filename and parsed_item.bufnr ~= 0 then
    parsed_item.filename = vim.api.nvim_buf_get_name(parsed_item.bufnr)
  end
  parsed_item.bufnr = nil
  parsed_item.valid = nil
  if parsed_item.module == "" then
    parsed_item.module = nil
  end
  if parsed_item.nr == -1 then
    parsed_item.nr = nil
  end
  if parsed_item.type == "" then
    parsed_item.type = nil
  end
  if parsed_item.pattern == "" then
    parsed_item.pattern = nil
  end
  if parsed_item.col == 0 then
    parsed_item.col = nil
  end
  if parsed_item.vcol == 0 then
    parsed_item.vcol = nil
  end
  if parsed_item.end_col == 0 then
    parsed_item.end_col = nil
  end
  if parsed_item.lnum == 0 then
    parsed_item.lnum = nil
  end
  if parsed_item.end_lnum == 0 then
    parsed_item.end_lnum = nil
  end

  for k, v in pairs(parsed_item) do
    item[k] = v
  end

  if self.postprocess then
    self.postprocess(item, { line = line })
  end
  parser.util.append_item(self.append, line, ctx)
  self.done = parser.STATUS.SUCCESS
  return self.consume and parser.STATUS.RUNNING or parser.STATUS.SUCCESS
end

return ExtractEfm
