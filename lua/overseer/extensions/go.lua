local overseer = require("overseer")
local constants = require("overseer.constants")
local parser = require("overseer.parser")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
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
      components = { "go_test_parser", "default_test" },
    }
  end,
}

M.go_stack_parser = {
  parser.skip_until("^panic: "),
  parser.skip_lines(3),
  parser.loop(
    { ignore_failure = false },
    parser.sequence(
      parser.extract({ append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"),
      parser.extract("^%s+([^:]+.go):([0-9]+)", "filename", "lnum")
    )
  ),
}

M.go_test_fail_parser = {
  parser.extract("^%s*([^:]+.go):([0-9]+):%s*(.+)$", "filename", "lnum", "text"),
}

M.go_test_parser = {
  name = "go_test_parser",
  description = "Parse go test output",
  slot = SLOT.RESULT,
  constructor = function()
    return {
      parser = overseer.parser.new({
        stacktrace = M.go_stack_parser,
        diagnostics = M.go_test_fail_parser,
      }),
      on_reset = function(self)
        self.parser:reset()
      end,
      on_output_lines = function(self, task, lines)
        self.parser:ingest(lines)
      end,
      on_exit = function(self, task, code)
        local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
        task:_set_result(status, self.parser:get_result())
      end,
    }
  end,
}

return M
