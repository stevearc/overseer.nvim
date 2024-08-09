local jobs = require("overseer.strategy._jobs")
local shell = require("overseer.shell")
local util = require("overseer.util")

local terminal = require("toggleterm.terminal")

---@class overseer.ToggleTermStrategy : overseer.Strategy
---@field private opts overseeer.ToggleTermStrategyOpts
---@field private term? Terminal
local ToggleTermStrategy = {}

---@class overseeer.ToggleTermStrategyOpts
---@field use_shell? boolean load user shell before running task
---@field size? number the size of the split if direction is vertical or horizontal
---@field direction? "vertical"|"horizontal"|"tab"|"float"
---@field highlights? table map to a highlight group name and a table of it's values
---@field auto_scroll? boolean automatically scroll to the bottom on task output
---@field close_on_exit? boolean close the terminal and delete terminal buffer (if open) after task exits
---@field quit_on_exit? "never"|"always"|"success" close the terminal window (if open) after task exits
---@field open_on_start? boolean toggle open the terminal automatically when task starts
---@field hidden? boolean cannot be toggled with normal ToggleTerm commands
---@field on_create? fun(term: table) function to execute on terminal creation

---Run tasks using the toggleterm plugin
---@param opts? overseeer.ToggleTermStrategyOpts
---@return overseer.Strategy
function ToggleTermStrategy.new(opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    use_shell = false,
    size = nil,
    direction = nil,
    highlights = nil,
    auto_scroll = nil,
    close_on_exit = false,
    quit_on_exit = "never",
    open_on_start = true,
    hidden = false,
    on_create = nil,
  })
  return setmetatable({
    opts = opts,
    term = nil,
  }, { __index = ToggleTermStrategy })
end

function ToggleTermStrategy:reset()
  if self.term then
    self.term:shutdown()
    self.term = nil
  end
end

function ToggleTermStrategy:get_bufnr()
  return self.term and self.term.bufnr
end

---@param task overseer.Task
function ToggleTermStrategy:start(task)
  local mode = vim.api.nvim_get_mode().mode
  local stdout_iter = util.get_stdout_line_iter()

  local function on_stdout(data)
    task:dispatch("on_output", data)
    local lines = stdout_iter(data)
    if not vim.tbl_isempty(lines) then
      task:dispatch("on_output_lines", lines)
    end
  end

  local cmd = task.cmd
  if type(cmd) == "table" then
    cmd = shell.escape_cmd(cmd, "strong")
  end

  local passed_cmd
  if not self.opts.use_shell then
    passed_cmd = cmd
  end

  self.term = terminal.Terminal:new({
    cmd = passed_cmd,
    env = task.env,
    highlights = self.opts.highlights,
    dir = task.cwd,
    direction = self.opts.direction,
    auto_scroll = self.opts.auto_scroll,
    close_on_exit = self.opts.close_on_exit,
    hidden = self.opts.hidden,
    on_create = function(t)
      local job_id = t.job_id
      jobs.register(job_id)

      if self.opts.on_create then
        self.opts.on_create(t)
      end

      if self.opts.use_shell then
        t:send(cmd)
        t:send("exit " .. (vim.o.shell:find("fish") and "$status" or "$?"))
      end
    end,
    on_stdout = function(t, job_id, d)
      if t ~= self.term then
        return
      end
      on_stdout(d)
    end,
    on_exit = function(t, j, c)
      jobs.unregister(j)
      if t ~= self.term then
        return
      end
      -- Feed one last line end to flush the output
      on_stdout({ "" })
      if vim.v.exiting == vim.NIL then
        task:on_exit(c)
      end

      local close = self.opts.quit_on_exit == "always"
        or (self.opts.quit_on_exit == "success" and c == 0)
      if close then
        t:close()
      end
    end,
  })

  if self.opts.open_on_start then
    self.term:toggle(self.opts.size)
  else
    self.term:spawn()
  end

  util.hack_around_termopen_autocmd(mode)
end

function ToggleTermStrategy:stop()
  if self.term and self.term.job_id then
    vim.fn.jobstop(self.term.job_id)
  end
end

function ToggleTermStrategy:dispose()
  if self.term then
    self.term:shutdown()
    self.term = nil
  end
end

---@param direction "float"|"tab"|"vertical"|"horizontal"
function ToggleTermStrategy:open_terminal(direction)
  if self.term then
    self.term:open(self.opts.size, direction)
  end
end

return ToggleTermStrategy
