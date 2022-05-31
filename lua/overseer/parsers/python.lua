local parser = require("overseer.parser")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local M = {}

local path_param = {
  "path",
  function(path)
    return vim.split(path, "%.")
  end,
}

local add_id = function(item)
  item.id = table.concat(item.path, ".") .. "." .. item.name
end

M.python_unittest = function()
  return {
    tests = {
      parser.parallel(
        -- Parse successes
        parser.loop(
          { ignore_failure = true },
          parser.sequence({
            parser.extract({
              append = false,
              postprocess = function(item)
                add_id(item)
                item.status = TEST_STATUS.SUCCESS
              end,
            }, "^([^%s]+) %((.+)%)$", "name", path_param),
            parser.test(" ok$"),
            parser.append(),
          })
        ),
        -- Parse failures at the end
        parser.loop(
          { ignore_failure = true },
          parser.sequence({
            parser.extract(
              {
                append = false,
                postprocess = add_id,
              },
              "^(FAIL): ([^%s]+) %((.+)%)",
              {
                "status",
                function()
                  return TEST_STATUS.FAILURE
                end,
              },
              "name",
              path_param
            ),
            parser.skip_until("^Traceback"),
            parser.extract_nested(
              "stacktrace",
              parser.loop(parser.sequence({
                parser.extract('%s*File "([^"]+)", line (%d+)', "filename", "lnum"),
                parser.skip_lines(1),
              }))
            ),
          })
        )
      ),
    },
    diagnostics = {
      parser.test("FAIL"),
      parser.skip_until("^Traceback"),
      parser.extract({ append = false }, '%s*File "([^"]+)", line (%d+)', "filename", "lnum"),
      parser.skip_until({ skip_matching_line = false }, "^[^%s]"),
      parser.extract("(.*)", "text"),
    },
  }
end

return M
