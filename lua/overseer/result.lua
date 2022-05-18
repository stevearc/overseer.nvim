local constants = require("overseer.constants")
local STATUS = constants.STATUS
local M = {}

M.new_output_summarizer = function()
  return {
    any_stderr = false,
    on_reset = function(self)
      self.any_stderr = false
    end,
    _append_data = function(self, task, data)
      for i = #data, 1, -1 do
        local line = data[i]
        if line ~= "" then
          line = string.gsub(line, "\r", "")
          if i == 1 then
            task.summary = task.summary .. line
          else
            task.summary = line
          end
          break
        end
      end
    end,
    on_stderr = function(self, task, data)
      self.any_stderr = true
      self:_append_data(task, data)
    end,
    on_stdout = function(self, task, data)
      if self.any_stderr then
        return
      end
      self:_append_data(task, data)
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
