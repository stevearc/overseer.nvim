local files = require("overseer.files")
local parser = require("overseer.parser")
local tutils = require("overseer.testing.utils")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local M = {
  name = "go_test",
  is_filename_test = function(self, filename)
    return filename:match("_test%.go$") and not filename:match("^_") and not filename:match("^%.")
  end,
  is_workspace_match = function(self, dirname)
    for _, fname in ipairs({ "go.mod" }) do
      if files.exists(files.join(dirname, fname)) then
        return true
      end
    end
    return false
  end,
  run_test_dir = function(self, dirname)
    return {
      cmd = { "go", "test", "-v", string.format("%s/...", dirname) },
    }
  end,
  run_test_file = function(self, filename)
    return {
      cmd = { "go", "test", "-v", filename },
    }
  end,
  run_test_in_file = function(self, filename, test)
    return {
      cmd = { "go", "test", "-v", "-run", string.format("^%s$", test.name) },
    }
  end,
  find_tests = function(self, bufnr)
    return tutils.get_tests_from_ts_query(
      bufnr,
      "go",
      "overseer_go_test",
      [[
(package_clause (package_identifier) @name) @group

(function_declaration
  name: (identifier) @name (#lua-match? @name "^Test")) @test
]],
      function(item)
        return item.name
      end
    )
  end,
}

local status_map = {
  FAIL = TEST_STATUS.FAILURE,
  PASS = TEST_STATUS.SUCCESS,
  SKIP = TEST_STATUS.SKIPPED,
}
local qf_type_map = {
  FAIL = "E",
  PASS = "I",
  SKIP = "W",
}
local status_field = {
  "status",
  function(value)
    return status_map[value]
  end,
}
local duration_field = {
  "duration",
  function(x)
    return tonumber(x)
  end,
}
M.parser = function()
  return {
    tests = {
      parser.extract({
        append = false,
        regex = true,
        postprocess = function(item)
          item.id = item.name
        end,
      }, "\\v^\\=\\=\\= RUN\\s+([^[:space:]]+)$", "name"),
      parser.always(parser.parallel(
        -- Stop parsing output if we hit the end line
        parser.invert(parser.test({ regex = true }, "\\v^--- (FAIL|PASS|SKIP)")),
        parser.extract_multiline({ append = false }, "(.*)", "text")
      )),
      parser.extract(
        {
          regex = true,
          append = false,
        },
        "\\v^--- (FAIL|PASS|SKIP): ([^[:space:]]+) \\(([0-9\\.]+)s\\)",
        status_field,
        "name",
        duration_field
      ),
      parser.always(
        parser.sequence(
          parser.extract({ append = false }, "^panic: (.+)$", "text"),
          parser.skip_until("^goroutine%s"),
          parser.extract_nested(
            { append = false },
            "stacktrace",
            parser.loop(
              parser.sequence(
                parser.extract({ append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"),
                parser.extract("^%s+([^:]+.go):([0-9]+)", "filename", "lnum")
              )
            )
          )
        )
      ),
      parser.append(),
    },
    diagnostics = {
      parser.parallel(
        { break_on_first_failure = false, restart_children = true },
        -- parse diagnostics-looking lines
        parser.extract({
          -- Don't append them to the results, add them to a pending buffer
          append = function(results, item)
            if not results.pending_diagnostics then
              results.pending_diagnostics = {}
            end
            table.insert(results.pending_diagnostics, item)
          end,
        }, "^%s+([^:]+%.go):(%d+):%s?(.*)$", "filename", "lnum", "text"),

        -- when we hit the end of the test, update the type of all pending
        -- diagnostics and properly append them
        parser.extract({
          regex = true,
          append = function(results, item)
            if results.pending_diagnostics then
              for _, diag in ipairs(results.pending_diagnostics) do
                diag.type = qf_type_map[item.status]
                table.insert(results, diag)
              end
              results.pending_diagnostics = nil
            end
          end,
        }, "\\v^--- (FAIL|PASS|SKIP):", "status")
      ),
    },
  }
end

return M
