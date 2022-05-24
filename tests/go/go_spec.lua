local go = require("overseer.template.go")
local parser = require("overseer.parser")

describe("go", function()
  it("can parse test failures", function()
    local p = parser.new(go.go_test_fail_parser)
    p:ingest(vim.split(
      [[
my_test.go:307: Expected 'Something' received 'Nothing'
]],
      "\n"
    ))
    local result = p:get_result()
    local expected = {
      { filename = "my_test.go", lnum = 307, text = "Expected 'Something' received 'Nothing'" },
    }
    assert.equals(true, vim.deep_equal(expected, result))
  end)

  it("can parse stack traces", function()
    local p = parser.new(go.go_stack_parser)
    p:ingest(vim.split(
      [[
panic: err [recovered]
        panic: err

goroutine 23 [running]:
testing.tRunner.func1.2({0x53ee20, 0x599dd8})
        /home/stevearc/.local/share/go/src/testing/testing.go:1389 +0x24e
testing.tRunner.func1()
        /home/stevearc/.local/share/go/src/testing/testing.go:1392 +0x39f
panic({0x53ee20, 0x599dd8})
        /home/stevearc/.local/share/go/src/runtime/panic.go:838 +0x207
github.com/stevearc/text-crdt.(*listDocument).tryIntegratePending(0xc00006f380)
        /home/stevearc/ws/text-crdt/document.go:155 +0x13c
github.com/stevearc/text-crdt.(*listDocument).Integrate(0xc00006f380, {0x59b128?, 0xc0002cbe30})
        /home/stevearc/ws/text-crdt/document.go:130 +0x10c
github.com/stevearc/text-crdt_test.(*testUser).processIncoming(0xc000212a10)
        /home/stevearc/ws/text-crdt/fuzz_test.go:55 +0xbb
github.com/stevearc/text-crdt_test.(*testUser).makeRandomEdit(0xc000212a10)
        /home/stevearc/ws/text-crdt/fuzz_test.go:84 +0xb4
github.com/stevearc/text-crdt_test.runUserTest({0xc0004b6d50, 0x3, 0x7fb0f92a74b0?}, 0x14)
        /home/stevearc/ws/text-crdt/fuzz_test.go:138 +0x66a
github.com/stevearc/text-crdt_test.runSeededTest(0x4c35d3?, {0xc0005a2330, 0x3, 0xf?}, 0x5ba8f9?)
        /home/stevearc/ws/text-crdt/fuzz_test.go:180 +0x128
github.com/stevearc/text-crdt_test.runFuzzerTest(0xc000582680, 0x3, 0xc8, 0x477d37?)
        /home/stevearc/ws/text-crdt/fuzz_test.go:189 +0xc5
github.com/stevearc/text-crdt_test.TestThreeUsers(0xc0005829c0?)
        /home/stevearc/ws/text-crdt/fuzz_test.go:211 +0x28
testing.tRunner(0xc000582680, 0x571c88)
        /home/stevearc/.local/share/go/src/testing/testing.go:1439 +0x102
created by testing.(*T).Run
        /home/stevearc/.local/share/go/src/testing/testing.go:1486 +0x35f
FAIL    github.com/stevearc/text-crdt   0.295s
  ]],
      "\n"
    ))
    local result = p:get_result()
    -- stylua: ignore
    local expected = {
      {text = "testing.tRunner.func1.2", filename = "/home/stevearc/.local/share/go/src/testing/testing.go", lnum = 1389},
      {text = "testing.tRunner.func1", filename = "/home/stevearc/.local/share/go/src/testing/testing.go", lnum = 1392},
      {text = "panic", filename = "/home/stevearc/.local/share/go/src/runtime/panic.go", lnum = 838},
      {text = "github.com/stevearc/text-crdt.(*listDocument).tryIntegratePending", filename = "/home/stevearc/ws/text-crdt/document.go", lnum = 155},
      {text = "github.com/stevearc/text-crdt.(*listDocument).Integrate", filename = "/home/stevearc/ws/text-crdt/document.go", lnum = 130},
      {text = "github.com/stevearc/text-crdt_test.(*testUser).processIncoming", filename = "/home/stevearc/ws/text-crdt/fuzz_test.go", lnum = 55},
      {text = "github.com/stevearc/text-crdt_test.(*testUser).makeRandomEdit", filename = "/home/stevearc/ws/text-crdt/fuzz_test.go", lnum = 84},
      {text = "github.com/stevearc/text-crdt_test.runUserTest", filename = "/home/stevearc/ws/text-crdt/fuzz_test.go", lnum = 138},
      {text = "github.com/stevearc/text-crdt_test.runSeededTest", filename = "/home/stevearc/ws/text-crdt/fuzz_test.go", lnum = 180},
      {text = "github.com/stevearc/text-crdt_test.runFuzzerTest", filename = "/home/stevearc/ws/text-crdt/fuzz_test.go", lnum = 189},
      {text = "github.com/stevearc/text-crdt_test.TestThreeUsers", filename = "/home/stevearc/ws/text-crdt/fuzz_test.go", lnum = 211},
      {text = "testing.tRunner", filename = "/home/stevearc/.local/share/go/src/testing/testing.go", lnum = 1439},
      {text = "testing.(*T).Run", filename = "/home/stevearc/.local/share/go/src/testing/testing.go", lnum = 1486},
    }
    assert.equals(true, vim.deep_equal(expected, result))
  end)
end)
