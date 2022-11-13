local log = require("overseer.log")
local util = require("overseer.util")

local TerminalStrategy = {}

local cleanup_autocmd
local all_channels = {}

---@return overseer.Strategy
function TerminalStrategy.new()
  if not cleanup_autocmd then
    -- Neovim will send a SIGHUP to PTY processes on exit. Unfortunately, some programs handle
    -- SIGHUP (for a legitimate purpose) and do not terminate, which leaves orphaned processes after
    -- Neovim exits. To avoid this, we need to explicitly call jobstop(), which will send a SIGHUP,
    -- wait (controlled by KILL_TIMEOUT_MS in process.c, 2000ms at the time of writing), then send a
    -- SIGTERM (possibly also a SIGKILL if that is insufficient).
    cleanup_autocmd = vim.api.nvim_create_autocmd("VimLeavePre", {
      desc = "Clean up running overseer tasks on exit",
      callback = function()
        local job_ids = vim.tbl_keys(all_channels)
        log:debug("VimLeavePre clean up terminal tasks %s", job_ids)
        for _, chan_id in ipairs(job_ids) do
          vim.fn.jobstop(chan_id)
        end
        local start_wait = vim.loop.hrtime()
        -- This makes sure Neovim doesn't exit until it has successfully killed all child processes.
        vim.fn.jobwait(job_ids)
        local elapsed = (vim.loop.hrtime() - start_wait) / 1e6
        if elapsed > 1000 then
          log:warn(
            "Killing running tasks took %dms. One or more processes likely did not terminate on SIGHUP. See https://github.com/stevearc/overseer.nvim/issues/46",
            elapsed
          )
        end
      end,
    })
  end
  return setmetatable({
    bufnr = nil,
    chan_id = nil,
  }, { __index = TerminalStrategy })
end

function TerminalStrategy:reset()
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
  local chan_id
  local mode = vim.api.nvim_get_mode().mode
  local stdout_iter = util.get_stdout_line_iter()

  vim.api.nvim_buf_call(self.bufnr, function()
    local function on_stdout(data)
      task:dispatch("on_output", data)
      local lines = stdout_iter(data)
      if not vim.tbl_isempty(lines) then
        task:dispatch("on_output_lines", lines)
      end
    end
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
        all_channels[j] = nil
        if self.chan_id ~= j then
          return
        end
        log:debug("Task %s exited with code %s", task.name, c)
        -- Feed one last line end to flush the output
        on_stdout({ "" })
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

  -- It's common to have autocmds that enter insert mode when opening a terminal
  -- This is a hack so we don't end up in insert mode after starting a task
  vim.defer_fn(function()
    local new_mode = vim.api.nvim_get_mode().mode
    if new_mode ~= mode then
      if string.find(new_mode, "i") == 1 then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
        if string.find(mode, "v") == 1 or string.find(mode, "V") == 1 then
          vim.cmd([[normal! gv]])
        end
      end
    end
  end, 10)

  if chan_id == 0 then
    error(string.format("Invalid arguments for task '%s'", task.name))
  elseif chan_id == -1 then
    error(string.format("Command '%s' not executable", vim.inspect(task.cmd)))
  else
    all_channels[chan_id] = true
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
