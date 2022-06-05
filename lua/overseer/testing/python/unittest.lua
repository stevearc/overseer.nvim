local files = require("overseer.files")
local parser = require("overseer.parser")
local tutils = require("overseer.testing.utils")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local M = {
  name = "python_unittest",
  is_workspace_match = function(self, dirname)
    for _, fname in ipairs({ "setup.py", "setup.cfg", "pyproject.toml" }) do
      if files.exists(files.join(dirname, fname)) then
        return true
      end
    end
    return false
  end,
  get_cmd = function(self)
    return { "python", "-m", "unittest" }
  end,
  run_test_dir = function(self, dirname)
    return {
      cmd = self:get_cmd(),
      args = { "discover", "-b", "-v", "-s", dirname },
    }
  end,
  run_test_file = function(self, filename)
    return {
      cmd = self:get_cmd(),
      args = { "-b", "-v", filename },
    }
  end,
  run_single_test = function(self, test)
    return {
      cmd = self:get_cmd(),
      args = { "-b", "-v", test.id },
    }
  end,
  run_test_group = function(self, path)
    -- If running the top level path, that should actually re-run all tests
    if #path == 1 then
      return self:run_test_dir(vim.fn.getcwd(0))
    end
    local specifier = table.concat(path, ".")
    return {
      cmd = self:get_cmd(),
      args = { "-b", "-v", specifier },
    }
  end,
  find_tests = function(self, bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local relfile = vim.fn.fnamemodify(filename, ":.:r")
    local path_to_file = vim.split(relfile, files.sep)
    return tutils.get_tests_from_ts_query(
      bufnr,
      "python",
      "overseer_python_unittest",
      [[
(class_definition
  name: (identifier) @name (#lua-match? @name "^Test")) @group

(function_definition
  name: (identifier) @name (#lua-match? @name "^test_")) @test
]],
      function(item)
        item.path = vim.list_extend(vim.deepcopy(path_to_file), item.path)
        return string.format("%s.%s", table.concat(item.path, "."), item.name)
      end
    )
  end,
}

local path_param = {
  "path",
  function(path)
    return vim.split(path, "%.")
  end,
}

local str_to_status = {
  ok = TEST_STATUS.SUCCESS,
  ERROR = TEST_STATUS.FAILURE,
  FAIL = TEST_STATUS.FAILURE,
  skipped = TEST_STATUS.SKIPPED,
}
local status_param = {
  "status",
  function(value)
    return str_to_status[value]
  end,
}

local add_id = function(item)
  item.id = table.concat(item.path, ".") .. "." .. item.name
end

M.parser = function()
  return {
    tests = {
      parser.parallel(
        -- Parse results as they come in
        parser.loop(
          { ignore_failure = true },
          parser.sequence({
            parser.extract({
              postprocess = function(item)
                add_id(item)
              end,
            }, "^([^%s]+) %((.+)%) %.%.%. ([^%s]+)$", "name", path_param, status_param),
          })
        ),
        -- Parse failures at the end
        parser.loop(
          { ignore_failure = true },
          parser.sequence({
            parser.skip_until("^==========+$"),
            parser.extract({
              append = false,
              postprocess = add_id,
            }, "^([^%s]+): ([^%s]+) %((.+)%)", status_param, "name", path_param),
            parser.skip_until("^Traceback"),
            parser.parallel(
              -- Extract summary of traceback as diagnostics
              parser.extract_nested(
                { append = false },
                "diagnostics",
                parser.sequence(
                  parser.extract(
                    { append = false },
                    '%s*File "([^"]+)", line (%d+)',
                    "filename",
                    "lnum"
                  ),
                  parser.skip_until({ skip_matching_line = false }, "^[^%s]"),
                  parser.extract("(.*)", "text")
                )
              ),
              -- Extract the entire stacktrace
              parser.extract_nested(
                { append = false },
                "stacktrace",
                parser.loop(parser.sequence({
                  parser.extract(
                    { append = false },
                    '%s*File "([^"]+)", line (%d+)',
                    "filename",
                    "lnum"
                  ),
                  parser.extract("^%s*(.+)$", "text"),
                }))
              ),
              -- Extract the text
              parser.sequence(
                parser.skip_until({ skip_matching_line = false }, "^[^%s]"),
                -- Parse stdout/stderr until we hit ==== (next test) or ---- (test end)
                parser.always(
                  parser.parallel(
                    parser.invert(parser.test({ "^==========", "^---------" })),
                    parser.extract_multiline({ append = false }, "(.*)", "text")
                  )
                )
              )
            ),
            parser.append(),
          })
        )
      ),
    },
  }
end

return M
