local overseer = require("overseer")
local constants = require("overseer.constants")
local files = require("overseer.files")
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
      components = {"go_test_parser", "default_test" },
    }
  end,
}

M.go_test_parser = {
  name = "go_test_parser",
  description = "Parse go test output",
  slot = SLOT.RESULT,
  constructor = function()
    return {
      result = { quickfix = {} },
      parsing_stack = false,
      on_reset = function(self)
        self.result = { quickfix = {} }
        self.parsing_stack = false
        self.stack_func = nil
      end,
      on_output_lines = function(self, task, lines)
        for _, line in ipairs(lines) do
          if self.parsing_stack then
            if self.stack_func then
              local fname, lnum = line:match("^%s+([^:]+.go):([0-9]+)")
              if fname and files.is_subpath(task.cmd_dir, fname) then
                table.insert(self.result.stacktrace, {
                  filename = fname,
                  lnum = tonumber(lnum),
                  text = string.format("%s()", self.stack_func),
                })
              end
              self.stack_func = nil
            else
              self.stack_func = line:match("^(.+)%(.+%)$")
            end
          else
            local fname, lnum, msg = line:match("^%s*([^:]+.go):([0-9]+):%s*(.+)$")
            if fname then
              table.insert(self.result.quickfix, {
                filename = fname,
                lnum = tonumber(lnum),
                text = msg,
                type = "E",
              })
            end
            msg = line:match("^panic: (.+)")
            if msg then
              self.parsing_stack = true
              self.result.stacktrace = {}
            end
          end
        end
      end,
      on_exit = function(self, task, code)
        local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
        task:_set_result(status, self.result)
      end,
    }
  end,
}

return M
