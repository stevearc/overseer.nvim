local component = require("overseer.component")
local constants = require("overseer.constants")
local form = require("overseer.form")
local log = require("overseer.log")
local task_list = require("overseer.task_list")
local util = require("overseer.util")

local STATUS = constants.STATUS

local Task = {}

local next_id = 1

Task.ordered_params = { "cmd", "cwd" }
Task.params = {
  cmd = {},
  cwd = {
    optional = true,
  },
}

function Task.new_uninitialized(opts)
  opts = opts or {}
  vim.validate({
    -- cmd can be table or string
    args = { opts.args, "t", true },
    cwd = { opts.cwd, "s", true },
    env = { opts.env, "t", true },
    name = { opts.name, "s", true },
    components = { opts.components, "t", true },
    metadata = { opts.metadata, "t", true },
  })

  if not opts.components then
    opts.components = { "default" }
  end
  if opts.args then
    if type(opts.cmd) == "string" then
      local escaped = vim.tbl_map(opts.args, function(arg)
        return vim.fn.shellescape(arg)
      end)
      opts.cmd = string.format("%s %s", opts.cmd, table.concat(escaped, " "))
    else
      opts.cmd = vim.deepcopy(opts.cmd)
      vim.list_extend(opts.cmd, opts.args)
    end
  end
  local name = opts.name
  if not name then
    name = type(opts.cmd) == "table" and table.concat(opts.cmd, " ") or opts.cmd
  end
  -- Build the instance data for the task
  local data = {
    result = nil,
    metadata = opts.metadata or {},
    _references = 0,
    status = STATUS.PENDING,
    cmd = opts.cmd,
    cwd = opts.cwd,
    env = opts.env,
    name = name,
    bufnr = nil,
    exit_code = nil,
    prev_bufnr = nil,
    components = {},
  }
  local task = setmetatable(data, { __index = Task })
  task:add_components(opts.components)
  return task
end

function Task.new(opts)
  local task = Task.new_uninitialized(opts)
  task.id = next_id
  next_id = next_id + 1
  task:dispatch("on_init")
  return task
end

local function stringify_result(res)
  if type(res) == "table" then
    if vim.tbl_isempty(res) then
      return "{}"
    else
      return string.format("{<%d items>}", vim.tbl_count(res))
    end
  else
    return string.format("%s", res)
  end
end

function Task:render(lines, highlights, detail)
  vim.validate({
    lines = { lines, "t" },
    detail = { detail, "n" },
  })
  table.insert(lines, string.format("%s: %s", self.status, self.name))
  table.insert(highlights, { "Overseer" .. self.status, #lines, 0, string.len(self.status) })
  table.insert(highlights, { "OverseerTask", #lines, string.len(self.status) + 2, -1 })

  if detail > 1 then
    local cmd_str = type(self.cmd) == "string" and self.cmd or table.concat(self.cmd, " ")
    table.insert(lines, cmd_str)
  end

  -- Render components
  if detail >= 3 then
    for _, comp in ipairs(self.components) do
      if comp.description then
        table.insert(lines, string.format("%s (%s)", comp.name, comp.description))
        table.insert(highlights, { "OverseerComponent", #lines, 0, string.len(comp.name) })
        table.insert(highlights, { "Comment", #lines, string.len(comp.name) + 1, -1 })
      else
        table.insert(lines, comp.name)
      end

      local comp_def = component.get(comp.name)
      for k, v in pairs(comp.params) do
        if k ~= 1 then
          table.insert(lines, form.render_field(comp_def.params[k], "  ", k, v))
        end
      end

      if comp.render then
        comp:render(self, lines, highlights, detail)
      end
    end
  else
    for _, comp in ipairs(self.components) do
      if comp.render then
        comp:render(self, lines, highlights, detail)
      end
    end
  end

  -- Render the result
  if self.result and not vim.tbl_isempty(self.result) then
    if detail == 1 then
      local pieces = {}
      for k, v in pairs(self.result) do
        table.insert(pieces, string.format("%s=%s", k, stringify_result(v)))
      end
      table.insert(lines, "Result: " .. table.concat(pieces, ", "))
    else
      table.insert(lines, "Result:")
      for k, v in pairs(self.result) do
        table.insert(lines, string.format("  %s = %s", k, stringify_result(v)))
      end
    end
  end
end

function Task:is_serializable()
  for _, comp in ipairs(self.components) do
    if comp.serialize == "fail" then
      return false
    end
  end
  return true
end

-- Returns the arguments require to create a clone of this task
function Task:serialize()
  local components = {}
  for _, comp in ipairs(self.components) do
    if comp.serialize == "fail" then
      error(string.format("Cannot serialize component %s", comp.name))
    elseif comp.serialize ~= "exclude" then
      table.insert(components, comp.params)
    end
  end
  return {
    name = self.name,
    metadata = self.metadata,
    cmd = self.cmd,
    cwd = self.cwd,
    env = self.env,
    components = components,
  }
end

function Task:clone()
  return Task.new(self:serialize())
end

function Task:add_component(comp)
  self:add_components({ comp })
end

function Task:add_components(components)
  vim.validate({
    components = { components, "t" },
  })
  local new_comps = component.resolve(components, self.components)
  for _, v in ipairs(component.load(new_comps)) do
    table.insert(self.components, v)
    if v.on_init then
      v:on_init(self)
    end
  end
end

function Task:set_component(comp)
  self:set_components({ comp })
end

-- Add components, overwriting any existing
function Task:set_components(components)
  vim.validate({
    components = { components, "t" },
  })
  for _, new_comp in ipairs(component.load(components)) do
    local found = false
    local replaced = false
    for i, comp in ipairs(self.components) do
      if comp.name == new_comp.name then
        found = true
        if component.params_should_replace(new_comp.params, comp.params) then
          if comp.dispose then
            comp:dispose(self)
          end
          self.components[i] = new_comp
          replaced = true
        end
      end
    end
    if replaced or not found then
      if not replaced then
        table.insert(self.components, new_comp)
      end
      if new_comp.on_init then
        new_comp:on_init(self)
      end
    end
  end
end

function Task:get_component(name)
  vim.validate({
    name = { name, "s" },
  })
  for _, v in ipairs(self.components) do
    if v.name == name then
      return v
    end
  end
end

function Task:remove_component(name)
  vim.validate({
    name = { name, "s" },
  })
  return self:remove_components({ name })
end

function Task:remove_components(names)
  vim.validate({
    names = { names, "t" },
  })
  local lookup = {}
  for _, name in ipairs(names) do
    lookup[name] = true
  end
  local indexes = {}
  local ret = {}
  for i, v in ipairs(self.components) do
    if lookup[v.name] then
      table.insert(indexes, i)
      table.insert(ret, v)
    end
  end
  -- Iterate backwards so removing one doesn't invalidate the indexes
  for i = #indexes, 1, -1 do
    local idx = indexes[i]
    local comp = table.remove(self.components, idx)
    if comp.on_dispose then
      comp:on_dispose(self)
    end
  end
  return ret
end

function Task:has_component(name)
  vim.validate({ name = { name, "s" } })
  local new_comps = component.resolve({ name }, self.components)
  return vim.tbl_isempty(new_comps)
end

function Task:is_pending()
  return self.status == STATUS.PENDING
end

function Task:is_running()
  return self.status == STATUS.RUNNING
end

function Task:is_complete()
  return self.status ~= STATUS.PENDING and self.status ~= STATUS.RUNNING
end

function Task:is_disposed()
  return self.status == STATUS.DISPOSED
end

function Task:reset(soft)
  if self:is_disposed() then
    error(string.format("Cannot reset %s task", self.status))
    return
  elseif not soft and self:is_running() then
    error(string.format("Cannot reset %s task", self.status))
    return
  end
  self.result = nil
  self.exit_code = nil
  -- Soft reset allows components & state to be reset without affecting the
  -- underlying process & buffer
  if not soft or not self:is_running() then
    self.status = STATUS.PENDING
    local bufnr = self.bufnr
    self.prev_bufnr = bufnr
    vim.defer_fn(function()
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end, 2000)
    self.bufnr = nil
    if self.chan_id then
      vim.fn.jobstop(self.chan_id)
      self.chan_id = nil
    end
  end
  task_list.touch_task(self)
  self:dispatch("on_reset", soft)
end

function Task:dispatch(name, ...)
  for _, comp in ipairs(self.components) do
    if type(comp[name]) == "function" then
      local ok, err = pcall(comp[name], comp, self, ...)
      if not ok then
        log:error("Task %s dispatch %s: %s", self.name, name, err)
      end
    end
  end
  if self.id and not self:is_disposed() then
    task_list.update(self)
  end
end

function Task:set_result(status, data)
  vim.validate({
    status = { status, "s" },
    data = { data, "t", true },
  })
  if not self:is_running() then
    return
  end
  self.status = status
  self.result = data or {}
  self:dispatch("on_result", status, self.result)
  if status == STATUS.SUCCESS or status == STATUS.FAILURE then
    self:dispatch("on_finish", status)
  end
end

function Task:inc_reference()
  self._references = self._references + 1
end

function Task:dec_reference()
  self._references = self._references - 1
end

function Task:dispose(force)
  vim.validate({
    force = { force, "b", true },
  })
  if self:is_disposed() then
    return false
  end
  if self._references > 0 and not force then
    log:debug("Not disposing task %s: has %d references", self.name, self._references)
    return false
  end
  local terminal_visible = util.is_bufnr_visible(self.bufnr)
  if not force then
    -- Can't dispose if the terminal is open
    if terminal_visible then
      log:debug("Not disposing task %s: buffer is visible", self.name)
      return false
    end
  end
  if self:is_running() then
    if force then
      -- If we're forcing the dispose, remove the ability to rerun, then stop,
      -- then dispose
      self:remove_component("on_rerun_handler")
      self:stop()
    else
      error("Cannot call dispose on running task")
    end
  end
  self.status = STATUS.DISPOSED
  log:debug("Disposing task %s", self.name)
  if self.chan_id then
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
  self:dispatch("on_dispose")
  task_list.remove(self)
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    if terminal_visible then
      vim.api.nvim_buf_set_option(self.bufnr, "bufhidden", "wipe")
    else
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
  end
  return true
end

function Task:rerun(force_stop)
  vim.validate({ force_stop = { force_stop, "b", true } })
  log:debug("Rerun task %s", self.name)
  if force_stop and self:is_running() then
    self:stop()
  end
  self:dispatch("on_request_rerun")
end

function Task:_on_exit(_job_id, code)
  self.chan_id = nil
  self.exit_code = code
  if not self:is_running() then
    -- We've already finalized, so we probably canceled this task
    return
  end
  self:dispatch("on_exit", code)
  -- We shouldn't hit this unless the components are missing a finalizer or
  -- they errored
  if self:is_running() then
    self:set_result(STATUS.FAILURE, { error = "Task did not produce a result before exiting" })
  end
end

function Task:start()
  if self:is_complete() then
    vim.notify(
      string.format("Cannot start task '%s' that has completed", self.name),
      vim.log.levels.ERROR
    )
    return false
  end
  if self:is_disposed() then
    vim.notify(
      string.format("Cannot start task '%s' that has been disposed", self.name),
      vim.log.levels.ERROR
    )
    return false
  end
  if self:is_running() then
    return false
  end
  self.bufnr = vim.api.nvim_create_buf(false, true)
  local chan_id
  local mode = vim.api.nvim_get_mode().mode
  local stdout_iter = util.get_stdout_line_iter()

  vim.api.nvim_buf_call(self.bufnr, function()
    log:debug("Starting task %s", self.name)
    chan_id = vim.fn.termopen(self.cmd, {
      cwd = self.cwd,
      env = self.env,
      on_stdout = function(j, d)
        self:dispatch("on_output", d)
        local lines = stdout_iter(d)
        if not vim.tbl_isempty(lines) then
          self:dispatch("on_output_lines", lines)
        end
      end,
      on_exit = function(j, c)
        log:debug("Task %s exited with code %s", self.name, c)
        -- Feed one last line end to flush the output
        self:dispatch("on_output", { "" })
        self:_on_exit(j, c)
      end,
    })
  end)
  vim.api.nvim_buf_set_option(self.bufnr, "buflisted", false)

  -- If this task's previous buffer was open in any wins, replace it
  if self.prev_bufnr then
    local prev_bufnr = self.prev_bufnr
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == prev_bufnr then
        -- If stickybuf is installed, make sure it doesn't interfere
        pcall(vim.api.nvim_win_del_var, win, "sticky_original_bufnr")
        pcall(vim.api.nvim_win_del_var, win, "sticky_bufnr")
        pcall(vim.api.nvim_win_del_var, win, "sticky_buftype")
        pcall(vim.api.nvim_win_del_var, win, "sticky_filetype")
        vim.api.nvim_win_set_buf(win, self.bufnr)
      end
    end
  end

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
  log:debug("Stopping task %s", self.name)
  self:set_result(STATUS.CANCELED)
  if self.chan_id then
    vim.fn.jobstop(self.chan_id)
    self.chan_id = nil
  end
  return true
end

return Task
