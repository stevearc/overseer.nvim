local log = require("overseer.log")
local overseer = require("overseer")
local util = require("overseer.util")

---@param proc vim.SystemObj
local function graceful_kill(proc)
  proc:kill("SIGTERM")
  vim.defer_fn(function()
    if not proc:is_closing() then
      proc:kill("SIGKILL")
    end
  end, 5000)
end

local cleanup_autocmd
local all_procs = {}
---@param proc vim.SystemObj
local function register(proc)
  if not cleanup_autocmd then
    cleanup_autocmd = vim.api.nvim_create_autocmd("VimLeavePre", {
      desc = "Clean up running overseer tasks on exit",
      callback = function()
        if #all_procs == 0 then
          return
        end
        log.debug("VimLeavePre clean up %d vim.system processes", #all_procs)
        for _, p in ipairs(all_procs) do
          graceful_kill(p)
        end
        local start_wait = vim.uv.now()
        if vim.wait(5001, function()
          return #all_procs == 0
        end) then
          return
        end

        local elapsed = (vim.uv.now() - start_wait)
        if elapsed > 1000 then
          log.warn(
            "Killing running vim.system tasks took %dms. One or more processes likely did not terminate on SIGHUP. See https://github.com/stevearc/overseer.nvim/issues/46",
            elapsed
          )
        end
      end,
    })
  end
  table.insert(all_procs, proc)
end

---@param proc vim.SystemObj
local function unregister(proc)
  for i, p in ipairs(all_procs) do
    if p == proc then
      table.remove(all_procs, i)
      return
    end
  end
end

---@class overseer.SystemStrategy : overseer.Strategy
---@field bufnr nil|integer
---@field handle nil|vim.SystemObj
---@field opts overseer.SystemStrategyOpts
local SystemStrategy = {}

---@class (exact) overseer.SystemStrategyOpts
---@field wrap_opts? vim.SystemOpts Opts that were passed to vim.system(). We should wrap them
---@field wrap_exit? fun(out: vim.SystemCompleted)

---@param opts nil|overseer.SystemStrategyOpts
---@return overseer.Strategy
function SystemStrategy.new(opts)
  local strategy = {
    bufnr = nil,
    job_id = nil,
    term_id = nil,
    opts = opts or {},
  }
  setmetatable(strategy, { __index = SystemStrategy })
  ---@type overseer.SystemStrategy
  return strategy
end

function SystemStrategy:reset()
  if self.bufnr then
    util.soft_delete_buf(self.bufnr)
    self.bufnr = nil
  end
  if self.handle then
    graceful_kill(self.handle)
    self.handle = nil
  end
end

function SystemStrategy:get_bufnr()
  return self.bufnr
end

---@param task overseer.Task
function SystemStrategy:start(task)
  local wrap = self.opts.wrap_opts or {}

  if not self.bufnr then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[self.bufnr].modifiable = false
  end

  local stdout_iter = util.get_stdout_line_iter()

  ---@param data string
  local on_output = vim.schedule_wrap(function(data)
    -- Update the buffer
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
    if not wrap.text then
      data = data:gsub("\r", "")
    end
    local raw_data = vim.split(data, "\n")
    local lines = raw_data
    lines[1] = end_line .. lines[1]
    vim.bo[self.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(self.bufnr, -2, -1, true, lines)
    vim.bo[self.bufnr].modifiable = false
    vim.bo[self.bufnr].modified = false

    -- Scroll to end of updated windows so we can tail output
    local lnum = line_count + #lines - 1
    local col = vim.api.nvim_strwidth(lines[#lines])
    for _, winid in ipairs(trail_wins) do
      vim.api.nvim_win_set_cursor(winid, { lnum, col })
    end

    -- Send output to task
    task:dispatch("on_output", raw_data)
    local iter_lines = stdout_iter(raw_data)
    if not vim.tbl_isempty(iter_lines) then
      task:dispatch("on_output_lines", iter_lines)
    end
  end)

  local handle
  local outputs = {}
  if wrap.stdout == nil or wrap.stdout == true then
    outputs.stdout = {}
  end
  if wrap.stderr == nil or wrap.stderr == true then
    outputs.stderr = {}
  end

  local function output_fn(channel)
    return function(err, data)
      if type(wrap[channel]) == "function" then
        local ok, cb_err = pcall(wrap[channel], err, data)
        if not ok then
          vim.schedule(function()
            log.error("Error in %s %s callback: %s", task.name, channel, cb_err)
          end)
        end
      end
      if outputs[channel] and data then
        table.insert(outputs[channel], data)
      end
      if err then
        vim.schedule(function()
          log.error("Error in %s %s callback: %s", task.name, channel, err)
        end)
      end
      if self.handle == handle and data then
        on_output(data)
      end
    end
  end

  local opts = vim.tbl_extend("force", wrap, {
    cwd = task.cwd,
    env = task.env,
    stdout = output_fn("stdout"),
    stderr = output_fn("stderr"),
  })
  ---@param out vim.SystemCompleted
  local function on_exit(out)
    -- If we patched the opts to include a stdout/stderr callback function where there was none
    -- before, we need to manually set those values on the SystemCompleted object
    if not out.stdout and outputs.stdout then
      out.stdout = table.concat(outputs.stdout)
    end
    if wrap.stderr and outputs.stderr then
      out.stderr = table.concat(outputs.stderr)
    end

    if self.opts.wrap_exit then
      self.opts.wrap_exit(out)
    end
    unregister(handle)
    if self.handle ~= handle then
      return
    end

    -- The rest of this needs to not happen in a fast event
    vim.schedule(function()
      log.debug("Task %s exited with code %s", task.name, out.code)
      -- Feed one last line end to flush the output
      on_output("\n")
      vim.bo[self.bufnr].modifiable = true
      vim.api.nvim_buf_set_lines(
        self.bufnr,
        -1,
        -1,
        true,
        { string.format("[Process exited %d]", out.code), "" }
      )
      vim.bo[self.bufnr].modifiable = false
      vim.bo[self.bufnr].modified = false
      self.handle = nil
      -- If we're exiting vim, don't call the on_exit handler
      -- We manually kill processes during VimLeavePre cleanup, and we don't want to trigger user
      -- code because of that
      if vim.v.exiting == vim.NIL then
        ---@diagnostic disable-next-line: invisible
        task:on_exit(out.code)
      end
    end)
  end

  local cmd = task.cmd
  ---@cast cmd string[]
  handle = overseer.builtin.system(cmd, opts, on_exit)

  local raw_wait = handle.wait
  -- NOTE: In practice the .stdout/.stderr patching done in on_exit is all we need, because the same
  -- object is returned from wait(). However, we're patching the wait function just in case the
  -- internal implementation changes at some point.
  handle.wait = function(p, timeout)
    local out = raw_wait(p, timeout)
    -- If we patched the opts to include a stdout/stderr callback function where there was none
    -- before, we need to manually set those values on the SystemCompleted object
    if not out.stdout and outputs.stdout then
      out.stdout = table.concat(outputs.stdout)
    end
    if wrap.stderr and outputs.stderr then
      out.stderr = table.concat(outputs.stderr)
    end
    return out
  end

  self.handle = handle

  if not wrap.detach then
    register(self.handle)
  end
end

function SystemStrategy:stop()
  if self.handle then
    graceful_kill(self.handle)
    self.handle = nil
  end
end

function SystemStrategy:dispose()
  self:stop()
  util.soft_delete_buf(self.bufnr)
end

return SystemStrategy
