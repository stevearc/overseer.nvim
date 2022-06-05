local integration = require("overseer.testing.go.go_test")
local test_utils = require("tests.testing.integration_test_utils")

describe("go_test", function()
  it("parses test output", function()
    local output = [[
=== RUN   TestSucceed
--- PASS: TestSucceed (0.00s)
=== RUN   TestSkip
    sample_test.go:10: Skip test
--- SKIP: TestSkip (0.00s)
=== RUN   TestFail
    sample_test.go:14: This is a failure
--- FAIL: TestFail (0.00s)
=== RUN   TestPanic
    sample_test.go:18: This is some output
--- FAIL: TestPanic (0.00s)
panic: Crash [recovered]
        panic: Crash

goroutine 9 [running]:
testing.tRunner.func1.2({0x4fcd60, 0x5489b0})
        /home/stevearc/.local/share/go/src/testing/testing.go:1389 +0x24e
testing.tRunner.func1()
        /home/stevearc/.local/share/go/src/testing/testing.go:1392 +0x39f
panic({0x4fcd60, 0x5489b0})
        /home/stevearc/.local/share/go/src/runtime/panic.go:838 +0x207
command-line-arguments_test.TestPanic(0xc00012a340?)
        /home/stevearc/ws/overseer-test-frameworks/go/gotest/sample_test.go:19 +0x59
testing.tRunner(0xc00012a9c0, 0x527d80)
        /home/stevearc/.local/share/go/src/testing/testing.go:1439 +0x102
created by testing.(*T).Run
        /home/stevearc/.local/share/go/src/testing/testing.go:1486 +0x35f
FAIL    command-line-arguments  0.004s
FAIL
      ]]
    local results = test_utils.run_parser(integration, output)
    assert.are.same({
      tests = {
        {
          duration = 0,
          id = "TestSucceed",
          name = "TestSucceed",
          status = "SUCCESS",
        },
        {
          diagnostics = {
            {
              filename = "sample_test.go",
              lnum = 10,
              text = "Skip test",
              type = "W",
            },
          },
          duration = 0,
          id = "TestSkip",
          name = "TestSkip",
          status = "SKIPPED",
          text = "    sample_test.go:10: Skip test",
        },
        {
          diagnostics = {
            {
              filename = "sample_test.go",
              lnum = 14,
              text = "This is a failure",
              type = "E",
            },
          },
          duration = 0,
          id = "TestFail",
          name = "TestFail",
          status = "FAILURE",
          text = "    sample_test.go:14: This is a failure",
        },
        {
          diagnostics = {
            {
              filename = "sample_test.go",
              lnum = 18,
              text = "This is some output",
              type = "E",
            },
          },
          duration = 0,
          id = "TestPanic",
          name = "TestPanic",
          stacktrace = {
            {
              filename = "/home/stevearc/.local/share/go/src/testing/testing.go",
              lnum = 1389,
              text = "testing.tRunner.func1.2",
            },
            {
              filename = "/home/stevearc/.local/share/go/src/testing/testing.go",
              lnum = 1392,
              text = "testing.tRunner.func1",
            },
            {
              filename = "/home/stevearc/.local/share/go/src/runtime/panic.go",
              lnum = 838,
              text = "panic",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/go/gotest/sample_test.go",
              lnum = 19,
              text = "command-line-arguments_test.TestPanic",
            },
            {
              filename = "/home/stevearc/.local/share/go/src/testing/testing.go",
              lnum = 1439,
              text = "testing.tRunner",
            },
            {
              filename = "/home/stevearc/.local/share/go/src/testing/testing.go",
              lnum = 1486,
              text = "testing.(*T).Run",
            },
          },
          status = "FAILURE",
          text = "    sample_test.go:18: This is some output",
        },
      },
    }, results)
  end)
end)
