local log = require("overseer.log")
local jobs = require("overseer.strategy._jobs")
local util = require("overseer.util")

local JobstartStrategy = {}

---@return overseer.Strategy
function JobstartStrategy.new(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    preserve_output = false,
  })
  return setmetatable({
    bufnr = nil,
    job_id = nil,
    term_id = nil,
    opts = opts,
  }, { __index = JobstartStrategy })
end

function JobstartStrategy:reset()
  if self.bufnr and not self.opts.preserve_output then
    util.soft_delete_buf(self.bufnr)
    self.bufnr = nil
    self.term_id = nil
  end
  if self.job_id then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end
end

function JobstartStrategy:get_bufnr()
  return self.bufnr
end

---@param task overseer.Task
function JobstartStrategy:start(task)
  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    local mode = vim.api.nvim_get_mode().mode
    local term_id
    util.run_in_fullscreen_win(self.bufnr, function()
      term_id = vim.api.nvim_open_term(self.bufnr, {
        on_input = function(_, _, _, data)
          pcall(vim.api.nvim_chan_send, self.job_id, data)
        end,
      })
    end)
    self.term_id = term_id
    util.hack_around_termopen_autocmd(mode)
  end

  local job_id
  local stdout_iter = util.get_stdout_line_iter()

  local function on_stdout(data)
    pcall(vim.api.nvim_chan_send, self.term_id, table.concat(data, "\r\n"))
    task:dispatch("on_output", data)
    local lines = stdout_iter(data)
    if not vim.tbl_isempty(lines) then
      task:dispatch("on_output_lines", lines)
    end
  end
  job_id = vim.fn.jobstart(task.cmd, {
    cwd = task.cwd,
    env = task.env,
    pty = true,
    -- Take 4 off the total width so it looks nice in the floating window
    width = vim.o.columns - 4,
    on_stdout = function(j, d)
      if self.job_id ~= j then
        return
      end
      on_stdout(d)
    end,
    on_stderr = function(j, d)
      if self.job_id ~= j then
        return
      end
      on_stdout(d)
    end,
    on_exit = function(j, c)
      jobs.unregister(j)
      if self.job_id ~= j then
        return
      end
      log:debug("Task %s exited with code %s", task.name, c)
      -- Feed one last line end to flush the output
      on_stdout({ "" })
      pcall(vim.api.nvim_chan_send, self.term_id, string.format("\r\n[Process exited %d]\r\n", c))
      self.job_id = nil
      -- If we're exiting vim, don't call the on_exit handler
      -- We manually kill processes during VimLeavePre cleanup, and we don't want to trigger user
      -- code because of that
      if vim.v.exiting == vim.NIL then
        task:on_exit(c)
      end
    end,
  })

  if job_id == 0 then
    error(string.format("Invalid arguments for task '%s'", task.name))
  elseif job_id == -1 then
    error(string.format("Command '%s' not executable", vim.inspect(task.cmd)))
  else
    jobs.register(job_id)
    self.job_id = job_id
  end
end

function JobstartStrategy:stop()
  if self.job_id then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end
end

function JobstartStrategy:dispose()
  self:stop()
  util.soft_delete_buf(self.bufnr)
end

return JobstartStrategy
