local overseer = require("overseer")
local constants = require("overseer.constants")
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

M.go_test_parser = {
  name = "go_test_parser",
  description = "Parse go test output",
  slot = SLOT.RESULT,
  constructor = function()
    return {
      result = { quickfix = {} },
      on_reset = function(self)
        self.result = { quickfix = {} }
      end,
      on_output_lines = function(self, task, lines)
        for _, line in ipairs(lines) do
          local fname, lnum, msg = line:match("^%s*([^:]+.go):([0-9]+):%s*(.+)$")
          if fname then
            table.insert(self.result.quickfix, {
              filename = fname,
              lnum = tonumber(lnum),
              text = msg,
              type = "E",
            })
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
