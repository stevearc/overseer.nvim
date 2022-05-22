local constants = require("overseer.constants")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
local M = {}

M.exit_code_finalizer = {
  name = "exit_code",
  description = "Exit code finalizer",
  slot = SLOT.RESULT,
  constructor = function()
    return {
      on_exit = function(self, task, code)
        local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
        task:_set_result(status, task.result or {})
      end,
    }
  end,
}

return M
