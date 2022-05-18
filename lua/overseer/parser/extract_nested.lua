local parser = require("overseer.parser")
local util = require("overseer.parser.util")
local ExtractNested = {
  desc = "Run a subparser and put the extracted results on the field of an item",
  doc_args = {
    {
      name = "opts",
      type = "object",
      desc = "Configuration options",
      position_optional = true,
      fields = {
        {
          name = "append",
          type = "boolean",
          desc = "After parsing, append the item to the results list. When false, the pending item will stick around.",
          default = true,
        },
        {
          name = "fail_on_empty",
          type = "boolean",
          desc = "Return FAILURE if there are no results from the child",
          default = true,
        },
      },
    },
    {
      name = "field",
      type = "string",
      desc = "The name of the field to add to the item",
    },
    {
      name = "child",
      type = "parser",
      desc = "The child parser node",
    },
  },
  examples = {
    {
      desc = [[Extract a golang test failure, then add the stacktrace to it (if present)]],
      code = [[
      {"extract",
        {
          regex = true,
          append = false,
        },
        "\\v^--- (FAIL|PASS|SKIP): ([^[:space:] ]+) \\(([0-9\\.]+)s\\)",
        "status",
        "name",
        "duration",
      },
      {"always",
        {"sequence",
          {"test", "^panic:"},
          {"skip_until", "^goroutine%s"},
          {"extract_nested",
            { append = false },
            "stacktrace",
            {"loop",
              {"sequence",
                {"extract",{ append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"},
                {"extract","^%s+([^:]+.go):([0-9]+)", "filename", "lnum"}
              }
            }
          }
        }
      }
      ]],
    },
  },
}

function ExtractNested.new(opts, field, child)
  if child == nil then
    child = field
    field = opts
    opts = {}
  end
  opts = vim.tbl_deep_extend("keep", opts, {
    append = true,
    fail_on_empty = true,
  })
  return setmetatable({
    child = util.hydrate(child),
    field = field,
    append = opts.append,
    fail_on_empty = opts.fail_on_empty,
    results = {},
    item = {},
  }, { __index = ExtractNested })
end

function ExtractNested:reset()
  self.done = nil
  self.results = {}
  self.item = {}
  self.child:reset()
end

function ExtractNested:ingest(line, ctx)
  if self.done then
    return self.done
  end
  local nested_ctx = {
    results = self.results,
    item = self.item,
  }
  local st = self.child:ingest(line, nested_ctx)
  if st == parser.STATUS.FAILURE then
    if not self.fail_on_empty or not vim.tbl_isempty(self.results) then
      st = parser.STATUS.SUCCESS
    end
  elseif st == parser.STATUS.RUNNING then
    if not vim.tbl_isempty(self.results) then
      -- As soon as we extract any values, make sure the field exists on the item
      ctx.item[self.field] = self.results
    end
    return st
  end

  if st == parser.STATUS.SUCCESS then
    ctx.item[self.field] = self.results
    parser.util.append_item(self.append, line, ctx)
  end

  self.done = st
  return self.done
end
return ExtractNested
