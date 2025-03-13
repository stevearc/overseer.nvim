local util = require("overseer.util")

---@class overseer.TestStrategy : overseer.Strategy
---@field bufnr integer
---@field task nil|overseer.Task
local TestStrategy = {}

---Strategy used for unit testing
---@return overseer.Strategy
function TestStrategy.new()
  local strategy = {
    task = nil,
    bufnr = vim.api.nvim_create_buf(false, true),
  }
  setmetatable(strategy, { __index = TestStrategy })
  ---@type overseer.TestStrategy
  return strategy
end

function TestStrategy:reset()
  self.task = nil
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, {})
end

function TestStrategy:get_bufnr()
  return self.bufnr
end

---Simulate output from the task
---@param lines string|string[]
function TestStrategy:send_output(lines)
  if type(lines) == "string" then
    lines = vim.split(lines, "\n")
  end
  vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, true, lines)
  self.task:dispatch("on_output", table.concat(lines, "\n"))
  self.task:dispatch("on_output_lines", lines)
end

---Simulate task exiting
---@param code nil|integer
function TestStrategy:send_exit(code)
  -- Feed one last line end to flush the output
  self.task:dispatch("on_output", "\n")
  self.task:dispatch("on_output_lines", { "" })
  self.task:on_exit(code or 0)
end

---@param task overseer.Task
function TestStrategy:start(task)
  self.task = task
end

function TestStrategy:stop()
  self:send_exit(1)
end

function TestStrategy:dispose()
  if self.task:is_running() then
    self:stop()
  end
  util.soft_delete_buf(self.bufnr)
end

return TestStrategy
