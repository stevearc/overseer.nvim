local integration = require("overseer.testing.lua.plenary_busted")
local test_utils = require("tests.testing.integration_test_utils")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

describe("plenary_busted", function()
  it("parses test output", function()
    local filename = debug.getinfo(1, "S").source:sub(2)
    local output = string.format(
      [[
Starting...Scheduling: tests/extensions/nvim_lua_spec.lua

========================================
Testing:        %s
Fail    ||      lua can parse test failures
            .../overseer.nvim/tests/testing/lua/plenary_busted_spec.lua:17: Expected objects to be the same.
            Passed in:
            (table: 0x7f0d8a8f2c90) { }
            Expected:
            (table: 0x7f0d8a8f3cc8) {
             *[1] = {
                [filename] = 'my_test.go'
                [lnum] = 7
                [text] = 'Expected 'Something' received 'Nothing'' } }

            stack traceback:
                ...overseer.nvim/tests/testing/lua/plenary_busted_spec.lua:17: in function <...overseer.nvim/tests/testing/lua/plenary_busted_spec.lua:5>
Success ||      go_test parses stack traces

Success:        1
Failed :        1
Errors :        0
========================================

========================================
Testing:        %s
Success ||      go_test parses test failures

Success:        1
Failed :        0
Errors :        0
========================================
    ]],
      filename,
      filename
    )
    local results = test_utils.run_parser(integration, output)
    assert.are.same({
      tests = {
        {
          id = string.format("%s:lua can parse test failures", filename),
          filename = filename,
          name = "lua can parse test failures",
          status = TEST_STATUS.FAILURE,
          diagnostics = {
            {
              filename = filename,
              lnum = 17,
              text = "Expected objects to be the same.\nPassed in:\n(table: 0x7f0d8a8f2c90) { }\nExpected:\n(table: 0x7f0d8a8f3cc8) {\n *[1] = {\n    [filename] = 'my_test.go'\n    [lnum] = 7\n    [text] = 'Expected 'Something' received 'Nothing'' } }",
            },
          },
          stacktrace = {
            {
              filename = filename,
              lnum = 17,
              text = "in function <...overseer.nvim/tests/testing/lua/plenary_busted_spec.lua:5>",
            },
          },
          text = ".../overseer.nvim/tests/testing/lua/plenary_busted_spec.lua:17: Expected objects to be the same.\nPassed in:\n(table: 0x7f0d8a8f2c90) { }\nExpected:\n(table: 0x7f0d8a8f3cc8) {\n *[1] = {\n    [filename] = 'my_test.go'\n    [lnum] = 7\n    [text] = 'Expected 'Something' received 'Nothing'' } }",
        },
        {
          id = string.format("%s:go_test parses stack traces", filename),
          filename = filename,
          name = "go_test parses stack traces",
          status = TEST_STATUS.SUCCESS,
        },
        {
          id = string.format("%s:go_test parses test failures", filename),
          filename = filename,
          name = "go_test parses test failures",
          status = TEST_STATUS.SUCCESS,
        },
      },
    }, results)
  end)
end)
