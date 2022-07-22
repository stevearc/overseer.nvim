local log = require("overseer.log")
local util = require("overseer.util")

local TerminalStrategy = {}

---@return overseer.Strategy
function TerminalStrategy.new()
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
        if self.chan_id ~= j then
          return
        end
        log:debug("Task %s exited with code %s", task.name, c)
        -- Feed one last line end to flush the output
        on_stdout({ "" })
        self.chan_id = nil
        task:on_exit(c)
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
    error("Invalid arguments for task '%s'", task.name)
  elseif chan_id == -1 then
    error(string.format("Command '%s' not executable", vim.inspect(task.cmd)))
  else
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
  local bufnr_visible = util.is_bufnr_visible(self.bufnr)
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    if bufnr_visible then
      vim.api.nvim_buf_set_option(self.bufnr, "bufhidden", "wipe")
    else
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
  end
end

return TerminalStrategy
