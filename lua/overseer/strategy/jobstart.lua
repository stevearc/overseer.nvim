local jobs = require("overseer.strategy._jobs")
local log = require("overseer.log")
local util = require("overseer.util")

---@class overseer.JobstartStrategy : overseer.Strategy
---@field bufnr nil|integer
---@field job_id nil|integer
---@field term_id nil|integer
---@field opts table
local JobstartStrategy = {}

---Run tasks using jobstart()
---@param opts nil|table
---    preserve_output boolean If true, don't clear the buffer when tasks restart
---    use_terminal boolean If false, use a normal non-terminal buffer to store the output. This may produce unwanted results if the task outputs terminal escape sequences.
---@return overseer.Strategy
function JobstartStrategy.new(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    preserve_output = false,
    use_terminal = true,
  })
  ---@type overseer.JobstartStrategy
  local strategy = {
    bufnr = nil,
    job_id = nil,
    term_id = nil,
    opts = opts,
  }
  setmetatable(strategy, { __index = JobstartStrategy })
  return strategy
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
    if self.opts.use_terminal then
      local mode = vim.api.nvim_get_mode().mode
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
      end)
      self.term_id = term_id
      util.hack_around_termopen_autocmd(mode)
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

  local job_id
  local stdout_iter = util.get_stdout_line_iter()

  local function on_stdout(data)
    -- Update the buffer
    if self.opts.use_terminal then
      pcall(vim.api.nvim_chan_send, self.term_id, table.concat(data, "\r\n"))
      vim.defer_fn(function()
        util.terminal_tail_hack(self.bufnr)
      end, 10)
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
  job_id = vim.fn.jobstart(task.cmd, {
    cwd = task.cwd,
    env = task.env,
    pty = self.opts.use_terminal,
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
      if self.opts.use_terminal then
        pcall(vim.api.nvim_chan_send, self.term_id, string.format("\r\n[Process exited %d]\r\n", c))
        -- HACK force terminal buffer to update
        -- see https://github.com/neovim/neovim/issues/23360
        vim.bo[self.bufnr].scrollback = vim.bo[self.bufnr].scrollback - 1
        vim.bo[self.bufnr].scrollback = vim.bo[self.bufnr].scrollback + 1
        util.terminal_tail_hack(self.bufnr)
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
      end
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
