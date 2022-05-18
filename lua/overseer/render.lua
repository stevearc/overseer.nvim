local registry = require("overseer.registry")
local M = {}

M.update_buffer = function(bufnr)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  local lines = {}
  for _, task in ipairs(registry.tasks) do
    table.insert(lines, task.name)
    table.insert(lines, task.status .. ": " .. task.summary)
    table.insert(lines, "----------")
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

return M
