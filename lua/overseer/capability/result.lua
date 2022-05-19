local constants = require("overseer.constants")
local STATUS = constants.STATUS
local CATEGORY = constants.CATEGORY
local M = {}

M.register_all = function()
  require("overseer.capability").register({
    name = "output_summary",
    description = "Summarize stdout/stderr",
    category = CATEGORY.RESULT,
    builder = M.output_summarizer,
  })
  require("overseer.capability").register({
    name = "exit_code",
    description = "Exit code finalizer",
    category = CATEGORY.RESULT,
    builder = M.exit_code_finalizer,
  })
end

M.output_summarizer = function()
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
      if not self.any_stderr then
        task.summary = ""
      end
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

M.exit_code_finalizer = function()
  return {
    on_exit = function(self, task, code)
      local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
      task:_set_result(status, task.result or {})
    end,
  }
end

return M
