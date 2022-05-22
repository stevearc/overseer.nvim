local component = require("overseer.component")
local constants = require("overseer.constants")
local registry = require("overseer.registry")
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

function Task.new(opts)
  opts = opts or {}
  vim.validate({
    cmd = { opts.cmd, "t" },
    cwd = { opts.cwd, "s", true },
    name = { opts.name, "s", true },
    components = { opts.components, "t", true },
  })

  if not opts.components then
    opts.components = { "default" }
  end
  local name = opts.name
  if not name then
    name = type(opts.cmd) == "table" and table.concat(opts.cmd, " ") or opts.cmd
  end
  -- Build the instance data for the task
  local data = {
    id = next_id,
    result = nil,
    _references = 0,
    disposed = false,
    status = STATUS.PENDING,
    cmd = opts.cmd,
    cwd = opts.cwd,
    name = name,
    bufnr = nil,
    prev_bufnr = nil,
    slots = {},
    components = {},
  }
  next_id = next_id + 1
  local task = setmetatable(data, { __index = Task })
  task:add_components(opts.components)
  task:dispatch("on_init")
  return task
end

function Task:render(lines, highlights, detail)
  vim.validate({
    lines = { lines, "t" },
    detail = { detail, "n" },
  })
  table.insert(lines, string.format("%s: %s", self.status, self.name))
  table.insert(highlights, { "Overseer" .. self.status, #lines, 0, string.len(self.status) })
  table.insert(highlights, { "OverseerTask", #lines, string.len(self.status) + 2, -1 })

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

      for k, v in pairs(comp.params) do
        if k ~= 1 then
          if type(v) == "table" and vim.tbl_islist(v) then
            v = table.concat(v, ", ")
          end
          table.insert(lines, string.format("  %s: %s", k, v))
        end
      end

      if comp.render then
        comp:render(self, lines, highlights, detail)
      end
    end
  else
    if detail == 2 then
      local names = {}
      for _, comp in ipairs(self.components) do
        table.insert(names, comp.name)
      end
      table.insert(lines, table.concat(names, ", "))
    end
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
        table.insert(pieces, string.format("%s=%s", k, v))
      end
      table.insert(lines, "Result: " .. table.concat(pieces, ", "))
    else
      table.insert(lines, "Result:")
      for k, v in pairs(self.result) do
        table.insert(lines, string.format("  %s = %s", k, v))
      end
    end
  end
end

-- Returns the arguments require to create a clone of this task
function Task:serialize()
  local components = {}
  for _, comp in ipairs(self.components) do
    table.insert(components, comp.params)
  end
  return {
    name = self.name,
    cmd = self.cmd,
    cwd = self.cwd,
    components = components,
  }
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
    -- Only add the component if the slot isn't taken
    if not v.slot or not self.slots[v.slot] then
      if v.slot then
        self.slots[v.slot] = v.name
      end
      table.insert(self.components, v)
      if v.on_init then
        v:on_init(self)
      end
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
      if new_comp.slot then
        self.slots[new_comp.slot] = new_comp.name
      end
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
    if comp.slot then
      self.slots[comp.slot] = nil
    end
    if comp.on_dispose then
      comp:on_dispose(self)
    end
  end
  return ret
end

function Task:remove_by_slot(slot)
  vim.validate({
    slot = { slot, "s" },
  })
  if self.slots[slot] then
    self:remove_component(self.slots[slot])
  end
end

function Task:has_slot(slot)
  vim.validate({
    slot = { slot, "s" },
  })
  return self.slots[slot] ~= nil
end

function Task:has_component(name)
  vim.validate({ name = { name, "s" } })
  local new_comps = component.resolve({ name }, self.components)
  return vim.tbl_isempty(new_comps)
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
  local bufnr = self.bufnr
  self.prev_bufnr = bufnr
  vim.defer_fn(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end, 2000)
  self.bufnr = nil
  self:dispatch("on_reset")
end

function Task:dispatch(name, ...)
  for _, comp in ipairs(self.components) do
    if type(comp[name]) == "function" then
      comp[name](comp, self, ...)
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
  -- Forcibly stop here because if we set the result before the process has
  -- exited, then we need to stop the process. Otherwise if we re-run the task
  -- the previous job may still be ongoing, and its callbacks will interfere
  -- with ours.
  vim.fn.jobstop(self.chan_id)
  self.chan_id = nil
  self:dispatch("on_finalize")
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
  if self.disposed or (self._references > 0 and not force) then
    return false
  end
  -- Can't dispose if the terminal is open
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == self.bufnr then
      return false
    end
  end
  self.disposed = true
  if self:is_running() then
    if force then
      -- If we're forcing the dispose, remove the ability to rerun, then stop,
      -- then dispose
      self:remove_component("rerun_trigger")
      self:stop()
    else
      error("Cannot call dispose on running task")
    end
  end
  self:dispatch("on_dispose")
  registry.remove_task(self)
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
  end
  return true
end

function Task:rerun(force_stop)
  vim.validate({ force_stop = { force_stop, "b", true } })
  if force_stop and self:is_running() then
    self:stop()
  end
  self:dispatch("on_request_rerun")
end

function Task:__on_exit(_job_id, code)
  if not self:is_running() then
    -- We've already finalized, so we probably canceled this task
    return
  end
  self:dispatch("on_exit", code)
  -- We shouldn't hit this unless the components are missing a finalizer or
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
  local stdout_iter = util.get_stdout_line_iter()

  vim.api.nvim_buf_call(self.bufnr, function()
    chan_id = vim.fn.termopen(self.cmd, {
      stdin = "null",
      cwd = self.cwd,
      on_stdout = function(j, d)
        self:dispatch("on_output", d)
        local lines = stdout_iter(d)
        if not vim.tbl_isempty(lines) then
          self:dispatch("on_output_lines", lines)
        end
      end,
      on_exit = function(j, c)
        self:__on_exit(j, c)
      end,
    })
  end)
  vim.api.nvim_buf_set_option(self.bufnr, "buflisted", false)

  -- If this task's previous buffer was open in any wins, replace it
  if self.prev_bufnr then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == self.prev_bufnr then
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
  self:_set_result(STATUS.CANCELED)
  return true
end

return Task
