local constants = require("overseer.constants")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
local M = {}

M.register_all = function()
  require("overseer.component").register(M.output_summarizer)
  require("overseer.component").register(M.exit_code_finalizer)
end

M.output_summarizer = {
  name = "output_summary",
  description = "Summarize stdout/stderr",
  builder = function()
    return {
      summary = "",
      on_reset = function(self)
        self.summary = ""
      end,
      on_output = function(self, task, data)
        for i = #data, 1, -1 do
          local line = data[i]
          if line ~= "" then
            line = string.gsub(line, "\r", "")
            if i == 1 then
              self.summary = self.summary .. line
            else
              self.summary = line
            end
            break
          end
        end
      end,
      render = function(self, task, lines, highlights, detail)
        if self.summary == "" then
          return
        end
        local sum_lines = vim.split(self.summary, "\n")
        local prefix = "out: "
        if detail == 1 then
          table.insert(lines, prefix .. sum_lines[#sum_lines])
          table.insert(highlights, { "Comment", #lines, 0, 4 })
          table.insert(highlights, { "OverseerOutput", #lines, 4, -1 })
        else
          for i = 1, #sum_lines do
            if sum_lines[i] ~= "" then
              table.insert(lines, prefix .. sum_lines[i])
              table.insert(highlights, { "Comment", #lines, 0, 4 })
              table.insert(highlights, { "OverseerOutput", #lines, 4, -1 })
            end
          end
        end
      end,
    }
  end,
}

M.exit_code_finalizer = {
  name = "exit_code",
  description = "Exit code finalizer",
  slot = SLOT.RESULT,
  builder = function()
    return {
      on_exit = function(self, task, code)
        local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
        task:_set_result(status, task.result or {})
      end,
    }
  end,
}

return M
