local constants = require("overseer.constants")
local util = require("overseer.util")
local STATUS = constants.STATUS
local M = {}

M.new_output_summarizer = function()
  return {
    name = 'stdout/stderr summarizer',
    any_stderr = false,
    stdout_iter = util.get_stdout_line_iter(),
    stderr_iter = util.get_stdout_line_iter(),
    on_reset = function(self)
      self.any_stderr = false
      self.stdout_iter = util.get_stdout_line_iter()
      self.stderr_iter = util.get_stdout_line_iter()
    end,
    on_stderr = function(self, task, data)
      self.any_stderr = true
      for _,line in ipairs(self.stderr_iter(data)) do
        task.summary = line
      end
    end,
    on_stdout = function(self, task, data)
      if self.any_stderr then
        return
      end
      for _,line in ipairs(self.stdout_iter(data)) do
        task.summary = line
      end
    end,
  }
end

M.new_exit_code_finalizer = function()
  return {
    on_exit = function(self, task, code)
      local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
      task:_set_result(status, {})
    end,
  }
end

return M
