local integration = require("overseer.testing.go.go_test")
local test_utils = require("tests.testing.integration_test_utils")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

describe("go_test", function()
  it("parses test failures", function()
    local output = [[=== RUN   TestUndoInsert
--- PASS: TestUndoInsert (0.00s)
=== RUN   TestUndoDelete
    undo_test.go:134: This is a log line
--- PASS: TestUndoDelete (0.21s)
=== RUN   TestUndoInsertDelete
    undo_test.go:171: Skip test
--- SKIP: TestUndoInsertDelete (0.00s)
=== RUN   TestDeleteUndoRedoLots
This is a print line
    undo_test.go:297: This is a log line
    undo_test.go:307: Expected 'Hello' received 'Heelllo'
--- FAIL: TestDeleteUndoRedoLots (0.00s)
=== RUN   TestDelete
--- PASS: TestDelete (0.00s)
FAIL
FAIL    command-line-arguments  0.002s
FAIL
      ]]
    local results = test_utils.run_parser(integration, output)
    assert.are.same({
      tests = {
        {
          id = "TestUndoInsert",
          name = "TestUndoInsert",
          duration = 0,
          status = TEST_STATUS.SUCCESS,
        },
        {
          id = "TestUndoDelete",
          name = "TestUndoDelete",
          duration = 0.21,
          status = TEST_STATUS.SUCCESS,
          text = "    undo_test.go:134: This is a log line",
        },
        {
          id = "TestUndoInsertDelete",
          name = "TestUndoInsertDelete",
          duration = 0,
          status = TEST_STATUS.SKIPPED,
          text = "    undo_test.go:171: Skip test",
        },
        {
          id = "TestDeleteUndoRedoLots",
          name = "TestDeleteUndoRedoLots",
          duration = 0,
          status = TEST_STATUS.FAILURE,
          text = "This is a print line\n    undo_test.go:297: This is a log line\n    undo_test.go:307: Expected 'Hello' received 'Heelllo'",
        },
        {
          id = "TestDelete",
          name = "TestDelete",
          duration = 0,
          status = TEST_STATUS.SUCCESS,
        },
      },
      diagnostics = {
        {
          filename = "undo_test.go",
          lnum = 134,
          text = "This is a log line",
          type = "I",
        },
        {
          filename = "undo_test.go",
          lnum = 171,
          text = "Skip test",
          type = "W",
        },
        {
          filename = "undo_test.go",
          lnum = 297,
          text = "This is a log line",
          type = "E",
        },
        {
          filename = "undo_test.go",
          lnum = 307,
          text = "Expected 'Hello' received 'Heelllo'",
          type = "E",
        },
      },
    }, results)
  end)

  it("parses stack traces", function()
    local output = [[=== RUN   TestUndoInsert
--- PASS: TestUndoInsert (0.00s)
=== RUN   TestThreeUsers
--- FAIL: TestThreeUsers (0.00s)
panic: SOME ERROR [recovered]
        panic: SOME ERROR

goroutine 34 [running]:
testing.tRunner.func1.2({0x53ee20, 0x599dd8})
        /home/stevearc/.local/share/go/src/testing/testing.go:1389 +0x24e
testing.tRunner.func1()
        /home/stevearc/.local/share/go/src/testing/testing.go:1392 +0x39f
panic({0x53ee20, 0x599dd8})
        /home/stevearc/.local/share/go/src/runtime/panic.go:838 +0x207
github.com/stevearc/text-crdt.(*listDocument).tryIntegratePending(0xc000228f60)
        /home/stevearc/ws/text-crdt/document.go:155 +0x13c
github.com/stevearc/text-crdt.(*listDocument).Integrate(0xc000228f60, {0x59b128?, 0xc0002a4060})
        /home/stevearc/ws/text-crdt/document.go:130 +0x10c
github.com/stevearc/text-crdt_test.(*testUser).processIncoming(0xc000226690)
        /home/stevearc/ws/text-crdt/fuzz_test.go:55 +0xbb
github.com/stevearc/text-crdt_test.(*testUser).makeRandomEdit(0xc000226690)
        /home/stevearc/ws/text-crdt/fuzz_test.go:84 +0xb4
github.com/stevearc/text-crdt_test.runUserTest({0xc0001feab0, 0x3, 0x7f5347bd1900?}, 0x14)
        /home/stevearc/ws/text-crdt/fuzz_test.go:138 +0x66a
github.com/stevearc/text-crdt_test.runSeededTest(0x4c35d3?, {0xc0005542e8, 0x3, 0xf?}, 0x5ba8f9?)
        /home/stevearc/ws/text-crdt/fuzz_test.go:180 +0x128
github.com/stevearc/text-crdt_test.runFuzzerTest(0xc000082d00, 0x3, 0xc8, 0x477d37?)
        /home/stevearc/ws/text-crdt/fuzz_test.go:189 +0xc5
github.com/stevearc/text-crdt_test.TestThreeUsers(0xc000083040?)
        /home/stevearc/ws/text-crdt/fuzz_test.go:211 +0x28
testing.tRunner(0xc000082d00, 0x571c88)
        /home/stevearc/.local/share/go/src/testing/testing.go:1439 +0x102
created by testing.(*T).Run
        /home/stevearc/.local/share/go/src/testing/testing.go:1486 +0x35f
FAIL    command-line-arguments  0.002s
FAIL
      ]]
    local results = test_utils.run_parser(integration, output)
    assert.are.same({
      tests = {
        {
          id = "TestUndoInsert",
          name = "TestUndoInsert",
          duration = 0,
          status = TEST_STATUS.SUCCESS,
        },
        {
          id = "TestThreeUsers",
          name = "TestThreeUsers",
          duration = 0,
          status = TEST_STATUS.FAILURE,
          text = "SOME ERROR [recovered]",
          stacktrace = {
            {
              text = "testing.tRunner.func1.2",
              filename = "/home/stevearc/.local/share/go/src/testing/testing.go",
              lnum = 1389,
            },
            {
              text = "testing.tRunner.func1",
              filename = "/home/stevearc/.local/share/go/src/testing/testing.go",
              lnum = 1392,
            },
            {
              text = "panic",
              filename = "/home/stevearc/.local/share/go/src/runtime/panic.go",
              lnum = 838,
            },
            {
              text = "github.com/stevearc/text-crdt.(*listDocument).tryIntegratePending",
              filename = "/home/stevearc/ws/text-crdt/document.go",
              lnum = 155,
            },
            {
              text = "github.com/stevearc/text-crdt.(*listDocument).Integrate",
              filename = "/home/stevearc/ws/text-crdt/document.go",
              lnum = 130,
            },
            {
              text = "github.com/stevearc/text-crdt_test.(*testUser).processIncoming",
              filename = "/home/stevearc/ws/text-crdt/fuzz_test.go",
              lnum = 55,
            },
            {
              text = "github.com/stevearc/text-crdt_test.(*testUser).makeRandomEdit",
              filename = "/home/stevearc/ws/text-crdt/fuzz_test.go",
              lnum = 84,
            },
            {
              text = "github.com/stevearc/text-crdt_test.runUserTest",
              filename = "/home/stevearc/ws/text-crdt/fuzz_test.go",
              lnum = 138,
            },
            {
              text = "github.com/stevearc/text-crdt_test.runSeededTest",
              filename = "/home/stevearc/ws/text-crdt/fuzz_test.go",
              lnum = 180,
            },
            {
              text = "github.com/stevearc/text-crdt_test.runFuzzerTest",
              filename = "/home/stevearc/ws/text-crdt/fuzz_test.go",
              lnum = 189,
            },
            {
              text = "github.com/stevearc/text-crdt_test.TestThreeUsers",
              filename = "/home/stevearc/ws/text-crdt/fuzz_test.go",
              lnum = 211,
            },
            {
              text = "testing.tRunner",
              filename = "/home/stevearc/.local/share/go/src/testing/testing.go",
              lnum = 1439,
            },
            {
              text = "testing.(*T).Run",
              filename = "/home/stevearc/.local/share/go/src/testing/testing.go",
              lnum = 1486,
            },
          },
        },
      },
      diagnostics = {},
    }, results)
  end)
end)
