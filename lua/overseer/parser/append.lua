local parser = require("overseer.parser")
local Append = {
  desc = "Append the current item to the results list",
  long_desc = "Normally the 'extract' node appends for you, but in cases where you use extract with `append = false`, you can explicitly append without extracting using this node.",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
        {
          name = "postprocess",
          type = "function",
          desc = "Call this function to do post-extraction processing on the values",
        },
      },
    },
  },
}

function Append.new(opts)
  opts = opts or {}
  return setmetatable({
    postprocess = opts.postprocess,
  }, { __index = Append })
end

function Append:reset() end

function Append:ingest(line, ctx)
  if self.postprocess then
    self.postprocess(ctx.item, ctx)
  end
  parser.util.append_item(true, line, ctx)
  return parser.STATUS.SUCCESS
end

return Append
