local jobs = require("overseer.strategy._jobs")
local util = require("overseer.util")

local terminal = require('toggleterm.terminal')

local ToggleTermStrategy = {}

---@return overseer.Strategy
function ToggleTermStrategy.new()
  return setmetatable({
    bufnr = nil,
    chan_id = nil,
  }, { __index = ToggleTermStrategy })
end

function ToggleTermStrategy:reset()
  util.soft_delete_buf(self.bufnr)
  self.bufnr = nil
  if self.chan_id then
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
end

function ToggleTermStrategy:get_bufnr()
  return self.bufnr
end

---@param task overseer.Task
function ToggleTermStrategy:start(task)
  local chan_id
  local mode = vim.api.nvim_get_mode().mode
  local stdout_iter = util.get_stdout_line_iter()

  local function on_stdout(data)
    task:dispatch("on_output", data)
    local lines = stdout_iter(data)
    if not vim.tbl_isempty(lines) then
      task:dispatch("on_output_lines", lines)
    end
  end

  local cmd = type(task.cmd) == "table" and unpack(task.cmd) or task.cmd
  local term = terminal.Terminal:new({
    cmd = cmd,
    cwd = task.cwd,
    env = task.env,
    on_stdout = function(j, d)
      if self.chan_id ~= j then
        return
      end
      on_stdout(d)
    end,
    on_exit = function(_, j, c)
      jobs.unregister(j)
      if self.chan_id ~= j then
        return
      end
      -- Feed one last line end to flush the output
      on_stdout({ "" })
      self.chan_id = nil
      if vim.v.exiting == vim.NIL then
        task:on_exit(c)
      end
    end,
    auto_scroll = true,
    close_on_exit = false,
    hidden = false,
  }):toggle()

  chan_id = term.job_id
  self.bufnr = term.bufnr

  util.hack_around_termopen_autocmd(mode)

  if chan_id == 0 then
    error(string.format("Invalid arguments for task '%s'", task.name))
  elseif chan_id == -1 then
    error(string.format("Command '%s' not executable", vim.inspect(task.cmd)))
  else
    jobs.unregister(chan_id)
    self.chan_id = chan_id
  end
end

function ToggleTermStrategy:stop()
  if self.chan_id then
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
end

function ToggleTermStrategy:dispose()
  self:stop()
  util.soft_delete_buf(self.bufnr)
end

return ToggleTermStrategy
