local M = {}

-- TODO
-- * Separate extracting the run result from notifying
-- * Side panel to display tasks
--
-- WISHLIST
-- * Sidebar with active tasks (for local directory? Or vim instance?)
-- * Run a test (file/suite/line) and notify. Can inspect all output.
-- * Run a test (file/suite/line) every time you save a file (debounce).
-- * :make every time you save a file (debounce).
-- * Save task templates somehow
-- * Load VSCode task definitions
-- * Store recent commands in history per-directory
--   * Can select & run task from recent history

-- Extract pass/fail
-- Capture stdout/stderr
-- Processors for stdout/stderr
-- Callback when complete
-- Can be re-invoked once complete (doing so while running will queue the re-invoke)

M.setup = function()
  -- nothing yet
end


local Task = {}

function Task.new(opts)
  opts = opts or {}
  vim.validate({
    cmd = { opts.cmd, 't'},
    name = { opts.name, 's', true},
  })
  -- Add defaults
  opts = vim.tbl_deep_extend('keep', opts, {})
  -- Build the instance data for the task
  data = {
    cmd = opts.cmd,
    name = opts.name or table.concat(opts.cmd, ' '),
    notifier = opts.notifier,
    old_bufnrs = {},
  }
  if not data.notifier or type(data.notifier) == 'string' then
    local notify = require('overseer.notify')
    data.notifier = notify.VimNotifyOnExit.new(data.notifier)
  end
  return setmetatable(data, {__index = Task})
end

function Task:_on_stdout(_job_id, data)
  if self.notifier.on_stdout then
    self.notifier:on_stdout(self, data)
  end
end

function Task:_on_stderr(_job_id, data)
  if self.notifier.on_stderr then
    self.notifier:on_stderr(self, data)
  end
end

function Task:_on_exit(_job_id, code)
  if self.notifier.on_exit then
    self.notifier:on_exit(self, code)
  end
  self.chan_id = nil
  table.insert(self.old_bufnrs, self.bufnr)
  self.bufnr = nil
end

function Task:start()
  if self.chan_id then
    return false
  end
  self.bufnr = vim.api.nvim_create_buf(false, true)
  local chan_id
  local mode = vim.api.nvim_get_mode().mode
  vim.api.nvim_buf_call(self.bufnr, function()
    chan_id = vim.fn.termopen(self.cmd, {
      stdin = "null",
      on_stdout = function(j, d)
        self:_on_stdout(j, d)
      end,
      on_stderr = function(j, d)
        self:_on_stderr(j, d)
      end,
      on_exit = function(j, c)
        self:_on_exit(j, c)
      end,
    })
  end)

  -- It's common to have autocmds that enter insert mode when opening a terminal
  vim.defer_fn(function()
    local new_mode = vim.api.nvim_get_mode().mode
    if new_mode ~= mode then
      if string.find(new_mode, 'i') == 1 then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<ESC>', true, true, true), 'n', false)
        if string.find(mode, 'v') == 1 or string.find(mode, 'V') == 1 then
          vim.cmd([[normal! gv]])
        end
      end
    end
  end, 10)

  if chan_id == 0 then
    vim.notify(string.format("Invalid arguments for task '%s'", self.name), vim.log.levels.ERROR)
    return false
  elseif chan_id == -1 then
    vim.notify(string.format("Command '%s' not executable", vim.inspect(self.cmd)), vim.log.levels.ERROR)
    return false
  else
    self.chan_id = chan_id
    return true
  end
end

function Task:stop()
  if self.chan_id then
    return false
  end
  vim.fn.jobstop(self.chan_id)
  self.chan_id = nil
  return true
end

M.new_task = function(opts)
  return Task.new(opts)
end

return M
