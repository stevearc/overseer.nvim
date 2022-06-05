local integration = require("overseer.testing.python.unittest")
local test_utils = require("tests.testing.integration_test_utils")

describe("python_unittest", function()
  it("parses test failures", function()
    local output = [[
test_error (tests.test_file.TestGroup) ... ERROR
test_fail (tests.test_file.TestGroup) ... FAIL
test_fail_with_output (tests.test_file.TestGroup) ... FAIL

Stdout:
This is some output

Stderr:
This is some stderr output
test_skip (tests.test_file.TestGroup) ... skipped 'Skip this test'
test_succeed (tests.test_file.TestGroup) ... ok

======================================================================
ERROR: test_error (tests.test_file.TestGroup)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py", line 16, in test_error
    self.foo.bar
AttributeError: 'TestGroup' object has no attribute 'foo'

======================================================================
FAIL: test_fail (tests.test_file.TestGroup)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py", line 13, in test_fail
    self.assertTrue(False)
AssertionError: False is not true

======================================================================
FAIL: test_fail_with_output (tests.test_file.TestGroup)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py", line 21, in test_fail_with_output
    self.assertTrue(False)
AssertionError: False is not true

Stdout:
This is some output

Stderr:
This is some stderr output

----------------------------------------------------------------------
Ran 5 tests in 0.001s

FAILED (failures=2, errors=1, skipped=1)
]]
    local results = test_utils.run_parser(integration, output)

    assert.are.same({
      tests = {
        {
          id = "tests.test_file.TestGroup.test_error",
          name = "test_error",
          path = { "tests", "test_file", "TestGroup" },
          status = "FAILURE",
        },
        {
          id = "tests.test_file.TestGroup.test_fail",
          name = "test_fail",
          path = { "tests", "test_file", "TestGroup" },
          status = "FAILURE",
        },
        {
          id = "tests.test_file.TestGroup.test_fail_with_output",
          name = "test_fail_with_output",
          path = { "tests", "test_file", "TestGroup" },
          status = "FAILURE",
        },
        {
          id = "tests.test_file.TestGroup.test_succeed",
          name = "test_succeed",
          path = { "tests", "test_file", "TestGroup" },
          status = "SUCCESS",
        },
        {
          diagnostics = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py",
              lnum = 16,
              text = "AttributeError: 'TestGroup' object has no attribute 'foo'",
            },
          },
          id = "tests.test_file.TestGroup.test_error",
          name = "test_error",
          path = { "tests", "test_file", "TestGroup" },
          stacktrace = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py",
              lnum = 16,
              text = "self.foo.bar",
            },
          },
          status = "FAILURE",
          text = "AttributeError: 'TestGroup' object has no attribute 'foo'\n",
        },
        {
          diagnostics = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py",
              lnum = 13,
              text = "AssertionError: False is not true",
            },
          },
          id = "tests.test_file.TestGroup.test_fail",
          name = "test_fail",
          path = { "tests", "test_file", "TestGroup" },
          stacktrace = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py",
              lnum = 13,
              text = "self.assertTrue(False)",
            },
          },
          status = "FAILURE",
          text = "AssertionError: False is not true\n",
        },
        {
          diagnostics = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py",
              lnum = 21,
              text = "AssertionError: False is not true",
            },
          },
          id = "tests.test_file.TestGroup.test_fail_with_output",
          name = "test_fail_with_output",
          path = { "tests", "test_file", "TestGroup" },
          stacktrace = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/python/unittest/tests/test_file.py",
              lnum = 21,
              text = "self.assertTrue(False)",
            },
          },
          status = "FAILURE",
          text = "AssertionError: False is not true\n\nStdout:\nThis is some output\n\nStderr:\nThis is some stderr output\n",
        },
      },
    }, results)
  end)
end)
