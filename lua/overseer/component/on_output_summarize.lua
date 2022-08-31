local task_list = require("overseer.task_list")
local util = require("overseer.util")

---@param bufnr integer
---@param num_lines integer
---@return string[]
local function get_last_lines(bufnr, num_lines)
  num_lines = math.min(num_lines, vim.api.nvim_buf_line_count(bufnr))
  local lines = vim.api.nvim_buf_get_lines(bufnr, -1 - num_lines, -1, false)
  local num_empty = 0
  while not vim.tbl_isempty(lines) and lines[#lines] == "" do
    table.remove(lines)
    num_empty = num_empty + 1
  end
  if num_empty > 0 then
    lines = vim.list_extend(
      vim.api.nvim_buf_get_lines(bufnr, -1 - num_lines - num_empty, -1 - num_lines, false),
      lines
    )
  end
  return lines
end

return {
  desc = "Summarize task output in the task list",
  params = {
    max_lines = {
      desc = "Number of lines of output to show when detail > 1",
      type = "integer",
      default = 4,
      validate = function(v)
        return v > 0
      end,
    },
  },
  constructor = function(params)
    return {
      lines = {},
      defer_update_lines = util.debounce(function(self, task, bufnr, num_lines)
        self.lines = get_last_lines(bufnr, num_lines)
        task_list.update(task)
      end, {
        delay = 10,
        reset_timer_on_call = true,
      }),
      on_reset = function(self)
        self.lines = {}
      end,
      on_output = function(self, task, data)
        local bufnr = task:get_bufnr()
        self.lines = get_last_lines(bufnr, params.max_lines)
        -- Update again after delay because the terminal buffer takes a few millis to be updated
        -- after output is received
        self.defer_update_lines(self, task, bufnr, params.max_lines)
      end,
      render = function(self, task, lines, highlights, detail)
        local prefix = "out: "
        if detail == 1 then
          local last_line = self.lines[#self.lines]
          if last_line and last_line ~= "" then
            table.insert(lines, prefix .. last_line)
            table.insert(highlights, { "Comment", #lines, 0, 4 })
            table.insert(highlights, { "OverseerOutput", #lines, 4, -1 })
          end
        else
          for _, line in ipairs(self.lines) do
            table.insert(lines, prefix .. line)
            table.insert(highlights, { "Comment", #lines, 0, 4 })
            table.insert(highlights, { "OverseerOutput", #lines, 4, -1 })
          end
        end
      end,
    }
  end,
}
