local jobs = require("overseer.strategy._jobs")
local log = require("overseer.log")
local util = require("overseer.util")

---@class overseer.TerminalStrategy : overseer.Strategy
---@field bufnr integer
---@field chan_id nil|integer
local TerminalStrategy = {}

---Run tasks using termopen()
---@return overseer.Strategy
function TerminalStrategy.new()
  return setmetatable({
    bufnr = nil,
    chan_id = nil,
  }, { __index = TerminalStrategy })
end

function TerminalStrategy:reset()
  util.soft_delete_buf(self.bufnr)
  self.bufnr = nil
  if self.chan_id then
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
end

function TerminalStrategy:get_bufnr()
  return self.bufnr
end

---@param task overseer.Task
function TerminalStrategy:start(task)
  self.bufnr = vim.api.nvim_create_buf(false, true)
  vim.b[self.bufnr].overseer_task = task.id
  local chan_id
  local mode = vim.api.nvim_get_mode().mode
  local stdout_iter = util.get_stdout_line_iter()

  local function on_stdout(data)
    task:dispatch("on_output", data)
    local lines = stdout_iter(data)
    if not vim.tbl_isempty(lines) then
      task:dispatch("on_output_lines", lines)
    end
    vim.defer_fn(function()
      util.terminal_tail_hack(self.bufnr)
    end, 10)
  end
  util.run_in_fullscreen_win(self.bufnr, function()
    chan_id = vim.fn.termopen(task.cmd, {
      cwd = task.cwd,
      env = task.env,
      on_stdout = function(j, d)
        if self.chan_id ~= j then
          return
        end
        on_stdout(d)
      end,
      on_exit = function(j, c)
        jobs.unregister(j)
        if self.chan_id ~= j then
          return
        end
        log:debug("Task %s exited with code %s", task.name, c)
        -- Feed one last line end to flush the output
        on_stdout({ "" })
        -- HACK force terminal buffer to update
        -- see https://github.com/neovim/neovim/issues/23360
        vim.bo[self.bufnr].scrollback = vim.bo[self.bufnr].scrollback - 1
        vim.bo[self.bufnr].scrollback = vim.bo[self.bufnr].scrollback + 1
        self.chan_id = nil
        -- If we're exiting vim, don't call the on_exit handler
        -- We manually kill processes during VimLeavePre cleanup, and we don't want to trigger user
        -- code because of that
        if vim.v.exiting == vim.NIL then
          task:on_exit(c)
        end
      end,
    })
  end)

  util.hack_around_termopen_autocmd(mode)

  if chan_id == 0 then
    error(string.format("Invalid arguments for task '%s'", task.name))
  elseif chan_id == -1 then
    error(string.format("Command '%s' not executable", vim.inspect(task.cmd)))
  else
    jobs.register(chan_id)
    self.chan_id = chan_id
  end
end

function TerminalStrategy:stop()
  if self.chan_id then
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
end

function TerminalStrategy:dispose()
  self:stop()
  util.soft_delete_buf(self.bufnr)
end

return TerminalStrategy
