local overseer = require("overseer")
local parser = require("overseer.parser")
local result = require("overseer.component.result")
local M = {}

M.go_test = {
  name = "go test",
  tags = { overseer.TAG.TEST },
  params = {
    target = { default = "./..." },
  },
  condition = {
    filetype = "go",
  },
  builder = function(self, params)
    return {
      cmd = { "go", "test", params.target },
      components = { "result_go_test", "default_test" },
    }
  end,
}

M.go_stack_parser = {
  parser.skip_until("^panic: "),
  parser.skip_lines(3),
  parser.loop(
    parser.sequence(
      parser.extract({ append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"),
      parser.extract("^%s+([^:]+.go):([0-9]+)", "filename", "lnum")
    )
  ),
}

M.go_test_fail_parser = {
  parser.extract("^%s*([^:]+.go):([0-9]+):%s*(.+)$", "filename", "lnum", "text"),
}

M.result_go_test = {
  name = "result_go_test",
  description = "Parse go test output",
  constructor = result.result_with_parser_constructor({
    stacktrace = M.go_stack_parser,
    diagnostics = M.go_test_fail_parser,
  }),
}

return M
