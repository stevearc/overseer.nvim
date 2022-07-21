local util = require("overseer.parser.util")
local SetDefaults = {
  desc = "A decorator that adds values to any items extracted by the child",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
        {
          name = "values",
          type = "object",
          desc = "Hardcoded key-value pairs to set as default values",
        },
        {
          name = "hoist_item",
          type = "boolean",
          desc = "Take the current pending item, and use its fields as the default key-value pairs",
          default = true,
        },
      },
    },
    {
      name = "child",
      type = "parser",
      desc = "The child parser node",
    },
  },
  examples = {
    {
      desc = [[Extract the filename from a header line, then for each line of output beneath it parse the test name + status, and also add the filename to each item]],
      code = [[
  {"sequence",
    {"extract", {append = false}, "^Test result (.+)$", "filename"}
    {"set_defaults",
      {"loop",
        {"extract", "^Test (.+): (.+)$", "test_name", "status"}
      }
    }
  }
      ]],
    },
  },
}

function SetDefaults.new(opts, child)
  if child == nil then
    child = opts
    opts = {}
  end
  opts = vim.tbl_deep_extend("keep", opts, {
    values = {},
    hoist_item = true,
  })
  vim.validate({
    values = { opts.values, "t" },
    hoist_item = { opts.hoist_item, "b" },
  })
  return setmetatable({
    default_values = opts.values,
    hoist_item = opts.hoist_item,
    current_defaults = nil,
    child = util.hydrate(child),
  }, { __index = SetDefaults })
end

function SetDefaults:reset()
  self.current_defaults = nil
  self.child:reset()
end

function SetDefaults:ingest(line, ctx)
  if not self.current_defaults then
    self.current_defaults = vim.deepcopy(self.default_values)
    if self.hoist_item then
      self.current_defaults = vim.tbl_extend("force", self.current_defaults, ctx.item)
    end
  end
  local prev_default_values = ctx.default_values
  ctx.default_values = vim.tbl_deep_extend("force", ctx.default_values or {}, self.current_defaults)
  local status = self.child:ingest(line, ctx)
  ctx.default_values = prev_default_values
  return status
end

return SetDefaults
