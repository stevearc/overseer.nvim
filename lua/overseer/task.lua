local config = require("overseer.config")
local constants = require("overseer.constants")
local registry = require("overseer.registry")

local STATUS = constants.STATUS

local Task = {}

local next_id = 1

function Task.new(opts)
  opts = opts or {}
  vim.validate({
    cmd = { opts.cmd, "t" },
    cwd = { opts.cwd, "s", true },
    name = { opts.name, "s", true },
    capabilities = { opts.capabilities, "t", true },
    overwrite_capabilities = { opts.overwrite_capabilities, "b", true },
    notifier = { opts.notifier, "t", true },
    summarizer = { opts.summarizer, "t", true },
    finalizer = { opts.finalizer, "t", true },
    rerunner = { opts.rerunner, "t", true },
  })

  if not opts.capabilities or not opts.overwrite_capabilities then
    opts.capabilities = opts.capabilities or {}
    if not opts.notifier then
      opts.notifier = config.get_default_notifier()
    end
    if not opts.summarizer then
      opts.summarizer = config.get_default_summarizer()
    end
    if not opts.finalizer then
      opts.finalizer = config.get_default_finalizer()
    end
    if not opts.rerunner then
      opts.rerunner = config.get_default_rerunner()
    end
    table.insert(opts.capabilities, opts.notifier)
    table.insert(opts.capabilities, opts.summarizer)
    table.insert(opts.capabilities, opts.finalizer)
    table.insert(opts.capabilities, opts.rerunner)
  elseif opts.notifier then
    vim.notify("Ignoring 'notifier' option when 'capabilities' is passed", vim.log.levels.WARN)
  end
  -- Build the instance data for the task
  local data = {
    id = next_id,
    summary = "",
    result = nil,
    status = STATUS.PENDING,
    cmd = opts.cmd,
    cwd = opts.cwd,
    name = opts.name or table.concat(opts.cmd, " "),
    capabilities = opts.capabilities,
  }
  next_id = next_id + 1
  local task = setmetatable(data, { __index = Task })
  task:dispatch("on_init")
  return task
end

function Task:is_running()
  return self.status == STATUS.RUNNING
end

function Task:is_complete()
  return self.status ~= STATUS.PENDING and self.status ~= STATUS.RUNNING
end

function Task:reset()
  if self:is_running() then
    error("Cannot reset task while running")
    return
  end
  self.status = STATUS.PENDING
  self.result = nil
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, {force = true})
  end
  self.bufnr = nil
  self.summary = ""
  self:dispatch("on_reset")
end

function Task:dispatch(name, ...)
  for _, cap in ipairs(self.capabilities) do
    if type(cap[name]) == "function" then
      cap[name](cap, self, ...)
    end
  end
  registry.update_task(self)
end

function Task:_set_result(status, data)
  vim.validate({
    status = { status, "s" },
    data = { data, "t", true },
  })
  if not self:is_running() then
    return
  end
  self.status = status
  self.result = data
  self:dispatch("on_result", status, data)

  -- Cleanup
  self.chan_id = nil
  self:dispatch("on_finalize")
end

function Task:dispose()
  if self:is_running() then
    error("Cannot call dispose on running task")
  end
  self:dispatch("on_dispose")
  registry.remove_task(self)
  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, {force = true})
  end
end

function Task:rerun(force_stop)
  vim.validate({ force_stop = { force_stop, "b", true } })
  if force_stop and self:is_running() then
    self:stop()
  end
  self:dispatch("on_request_rerun")
end

function Task:__on_stdout(_job_id, data)
  self:dispatch("on_stdout", data)
end

function Task:__on_stderr(_job_id, data)
  self:dispatch("on_stderr", data)
end

function Task:__on_exit(_job_id, code)
  if not self:is_running() then
    -- We've already finalized, so we probably canceled
    return
  end
  self:dispatch("on_exit", code)
  -- We shouldn't hit this unless the capabilities are missing a finalizer or
  -- they errored
  if self:is_running() then
    self:_set_result(STATUS.FAILURE, { error = "Task did not produce a result before exiting" })
  end
end

function Task:start()
  if self:is_complete() then
    vim.notify("Cannot start a task that has completed", vim.log.levels.ERROR)
    return false
  end
  if self:is_running() then
    return false
  end
  self.bufnr = vim.api.nvim_create_buf(false, true)
  local chan_id
  local mode = vim.api.nvim_get_mode().mode
  vim.api.nvim_buf_call(self.bufnr, function()
    chan_id = vim.fn.termopen(self.cmd, {
      stdin = "null",
      cwd = self.cwd,
      on_stdout = function(j, d)
        self:__on_stdout(j, d)
      end,
      on_stderr = function(j, d)
        self:__on_stderr(j, d)
      end,
      on_exit = function(j, c)
        self:__on_exit(j, c)
      end,
    })
  end)

  -- It's common to have autocmds that enter insert mode when opening a terminal
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
    vim.notify(string.format("Invalid arguments for task '%s'", self.name), vim.log.levels.ERROR)
    return false
  elseif chan_id == -1 then
    vim.notify(
      string.format("Command '%s' not executable", vim.inspect(self.cmd)),
      vim.log.levels.ERROR
    )
    return false
  else
    self.chan_id = chan_id
    self.status = STATUS.RUNNING
    self:dispatch("on_start")
    return true
  end
end

function Task:stop()
  if not self:is_running() then
    return false
  end
  local chan_id = self.chan_id
  self:_set_result(STATUS.CANCELED)
  vim.fn.jobstop(chan_id)
  return true
end

return Task
