local log = require("overseer.log")
local overseer = require("overseer")
local util = require("overseer.util")

local cleanup_autocmd
local all_channels = {}
local function register(job_id)
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
        log.debug("VimLeavePre clean up terminal tasks %s", job_ids)
        for _, chan_id in ipairs(job_ids) do
          vim.fn.jobstop(chan_id)
        end
        local start_wait = vim.uv.hrtime()
        -- This makes sure Neovim doesn't exit until it has successfully killed all child processes.
        vim.fn.jobwait(job_ids)
        local elapsed = (vim.uv.hrtime() - start_wait) / 1e6
        if elapsed > 1000 then
          log.warn(
            "Killing running tasks took %dms. One or more processes likely did not terminate on SIGHUP. See https://github.com/stevearc/overseer.nvim/issues/46",
            elapsed
          )
        end
      end,
    })
  end
  all_channels[job_id] = true
end

local function unregister(job_id)
  all_channels[job_id] = nil
end

---@class overseer.JobstartStrategy : overseer.Strategy
---@field bufnr nil|integer
---@field job_id nil|integer
---@field term_id nil|integer
---@field opts overseer.JobstartStrategyOpts
local JobstartStrategy = {}

---@class (exact) overseer.JobstartStrategyOpts
---@field preserve_output? boolean If true, don't clear the buffer when tasks restart
---@field use_terminal? boolean If false, use a normal non-terminal buffer to store the output. This may produce unwanted results if the task outputs terminal escape sequences.
---@field wrap_opts? table Opts that were passed to jobstart(). We should wrap them

---Run tasks using jobstart()
---@param opts nil|overseer.JobstartStrategyOpts
---@return overseer.Strategy
function JobstartStrategy.new(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    preserve_output = false,
    use_terminal = true,
  })
  local strategy = {
    bufnr = nil,
    job_id = nil,
    term_id = nil,
    pending_output = {},
    opts = opts,
  }
  setmetatable(strategy, { __index = JobstartStrategy })
  ---@type overseer.JobstartStrategy
  return strategy
end

function JobstartStrategy:reset()
  if self.bufnr and not self.opts.preserve_output then
    util.soft_delete_buf(self.bufnr)
    self.bufnr = nil
    self.term_id = nil
  end
  if self.job_id and self.job_id > 0 then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end
end

function JobstartStrategy:get_bufnr()
  return self.bufnr
end

---@return boolean
local function can_create_terminal()
  -- Only allow creating a terminal in normal mode when we are not in a floating win.
  -- Creating the terminal will exit visual/insert mode and can cause some dialogs to close.
  return vim.api.nvim_get_mode().mode == "n" and not util.is_floating_win(0)
end

local pending_terminal_jobs = {}
local function render_pending_terminals()
  if not can_create_terminal() then
    return
  end
  for _, strat in ipairs(pending_terminal_jobs) do
    strat:_create_terminal()
  end
  pending_terminal_jobs = {}
end

local created_autocmds = false
---@param strat overseer.JobstartStrategy
local function queue_terminal_creation(strat)
  table.insert(pending_terminal_jobs, strat)
  if created_autocmds then
    return
  end
  created_autocmds = true
  vim.api.nvim_create_autocmd("ModeChanged", {
    pattern = "*:n",
    callback = render_pending_terminals,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    callback = render_pending_terminals,
  })
end

function JobstartStrategy:_create_terminal()
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) or self.term_id then
    return
  end
  local term_id
  util.run_in_fullscreen_win(self.bufnr, function()
    term_id = vim.api.nvim_open_term(self.bufnr, {
      on_input = function(_, _, _, data)
        pcall(vim.api.nvim_chan_send, self.job_id, data)
        vim.defer_fn(function()
          util.terminal_tail_hack(self.bufnr)
        end, 10)
      end,
    })
    -- Set the scrollback to max
    vim.bo[self.bufnr].scrollback = 100000
    for _, data in ipairs(self.pending_output) do
      pcall(vim.api.nvim_chan_send, term_id, table.concat(data, "\r\n"))
    end
    self.pending_output = {}
  end)
  self.term_id = term_id
end

function JobstartStrategy:_init_buffer()
  local bufnr = vim.api.nvim_create_buf(false, true)
  self.bufnr = bufnr
  self.pending_output = {}
  if self.opts.use_terminal then
    if can_create_terminal() then
      self:_create_terminal()
    else
      queue_terminal_creation(self)
    end
  else
    vim.bo[self.bufnr].modifiable = false
    local function open_input()
      local prompt = vim.api.nvim_buf_get_lines(self.bufnr, -2, -1, true)[1]
      if prompt:match("^%s*$") then
        prompt = "Input: "
      end
      vim.ui.input({ prompt = prompt }, function(text)
        if text then
          pcall(vim.api.nvim_chan_send, self.job_id, text .. "\r")
        end
      end)
    end
    for _, lhs in ipairs({ "i", "I", "a", "A", "o", "O" }) do
      vim.keymap.set("n", lhs, open_input, { buffer = self.bufnr })
    end
  end
end

---@param task overseer.Task
function JobstartStrategy:start(task)
  local wrap_term = self.opts.wrap_opts and self.opts.wrap_opts.term
  local wrap = self.opts.wrap_opts or {}

  if wrap_term then
    -- If we are wrapping jobstart() and the user passed `term = true`, then they are intending to
    -- use the current buffer as the output display.
    self.bufnr = vim.api.nvim_get_current_buf()
  end
  if not self.bufnr then
    self:_init_buffer()
  end

  local stdout_iter = util.get_stdout_line_iter()

  local function on_stdout(data)
    -- Update the buffer
    if wrap_term then
      -- don't do anything
    elseif self.opts.use_terminal then
      if self.term_id then
        pcall(vim.api.nvim_chan_send, self.term_id, table.concat(data, "\r\n"))
        vim.defer_fn(function()
          util.terminal_tail_hack(self.bufnr)
        end, 10)
      else
        table.insert(self.pending_output, data)
      end
    else
      -- Track which wins we will need to scroll
      local trail_wins = {}
      local line_count = vim.api.nvim_buf_line_count(self.bufnr)
      for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == self.bufnr then
          if vim.api.nvim_win_get_cursor(winid)[1] == line_count then
            table.insert(trail_wins, winid)
          end
        end
      end
      local end_line = vim.api.nvim_buf_get_lines(self.bufnr, -2, -1, true)[1] or ""
      local end_lines = vim.tbl_map(util.clean_job_line, data)
      end_lines[1] = end_line .. end_lines[1]
      vim.bo[self.bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(self.bufnr, -2, -1, true, end_lines)
      vim.bo[self.bufnr].modifiable = false
      vim.bo[self.bufnr].modified = false

      -- Scroll to end of updated windows so we can tail output
      local lnum = line_count + #end_lines - 1
      local col = vim.api.nvim_strwidth(end_lines[#end_lines])
      for _, winid in ipairs(trail_wins) do
        vim.api.nvim_win_set_cursor(winid, { lnum, col })
      end
    end

    -- Send output to task
    task:dispatch("on_output", data)
    local lines = stdout_iter(data)
    if not vim.tbl_isempty(lines) then
      task:dispatch("on_output_lines", lines)
    end
  end

  local function coalesce(a, b)
    if a == nil then
      return b
    else
      return a
    end
  end

  local opts = vim.tbl_extend("force", wrap, {
    cwd = task.cwd,
    env = task.env,
    pty = coalesce(wrap.pty, self.opts.use_terminal),
    -- Take 4 off the total width so it looks nice in the floating window
    width = coalesce(wrap.width, vim.o.columns - 4),
    on_stdout = function(j, d, m)
      if wrap.on_stdout then
        wrap.on_stdout(j, d, m)
      end
      if self.job_id ~= j then
        return
      end
      on_stdout(d)
    end,
    on_stderr = function(j, d, m)
      if wrap.on_stderr then
        wrap.on_stderr(j, d, m)
      end
      if self.job_id ~= j then
        return
      end
      on_stdout(d)
    end,
    on_exit = function(j, c, m)
      if wrap.on_exit then
        wrap.on_exit(j, c, m)
      end
      unregister(j)
      if self.job_id ~= j then
        return
      end
      log.debug("Task %s exited with code %s", task.name, c)
      -- Feed one last line end to flush the output
      on_stdout({ "" })
      if self.opts.use_terminal then
        if self.term_id then
          pcall(
            vim.api.nvim_chan_send,
            self.term_id,
            string.format("\r\n[Process exited %d]\r\n", c)
          )
          -- HACK force terminal buffer to update
          -- see https://github.com/neovim/neovim/issues/23360
          vim.bo[self.bufnr].scrollback = vim.bo[self.bufnr].scrollback - 1
          vim.bo[self.bufnr].scrollback = vim.bo[self.bufnr].scrollback + 1
          util.terminal_tail_hack(self.bufnr)
        else
          table.insert(self.pending_output, { "", string.format("[Process exited %d]", c), "" })
        end
      else
        vim.bo[self.bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(
          self.bufnr,
          -1,
          -1,
          true,
          { string.format("[Process exited %d]", c), "" }
        )
        vim.bo[self.bufnr].modifiable = false
        vim.bo[self.bufnr].modified = false
      end
      self.job_id = nil
      -- If we're exiting vim, don't call the on_exit handler
      -- We manually kill processes during VimLeavePre cleanup, and we don't want to trigger user
      -- code because of that
      if vim.v.exiting == vim.NIL then
        ---@diagnostic disable-next-line: invisible
        task:on_exit(c)
      end
    end,
  })

  self.job_id = overseer.builtin.jobstart(task.cmd, opts)

  if self.job_id == 0 then
    log.error("Invalid arguments for task '%s'", task.name)
  elseif self.job_id == -1 then
    log.error("Command '%s' not executable", task.cmd)
  else
    register(self.job_id)
  end
end

function JobstartStrategy:stop()
  if self.job_id and self.job_id > 0 then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end
end

function JobstartStrategy:dispose()
  self:stop()
  util.soft_delete_buf(self.bufnr)
end

return JobstartStrategy
