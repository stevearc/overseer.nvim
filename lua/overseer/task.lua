local component = require("overseer.component")
local constants = require("overseer.constants")
local form = require("overseer.form")
local log = require("overseer.log")
local strategy = require("overseer.strategy")
local task_list = require("overseer.task_list")
local util = require("overseer.util")

local STATUS = constants.STATUS

---@class overseer.Task
---@field id number
---@field result? table
---@field metadata table
---@field status overseer.Status
---@field cmd string|string[]
---@field cwd? string
---@field env? table<string, string>
---@field strategy_defn nil|string|table
---@field strategy? overseer.Strategy
---@field name string
---@field bufnr number|nil
---@field exit_code number|nil
---@field components overseer.Component[]
local Task = {}

local next_id = 1

Task.ordered_params = { "cmd", "cwd" }
---@type overseer.Params
Task.params = {
  -- It's kind of a hack to specify a delimiter without type = 'list'. This is
  -- so the task editor displays nicely if the value is a list OR a string
  cmd = { delimiter = " " },
  cwd = {
    optional = true,
  },
}

---@class overseer.TaskDefinition
---@field args? string[]
---@field name? string
---@field cwd? string
---@field env? table<string, string>
---@field strategy? string|table
---@field metadata? table
---@field components? table TODO more specific type

---Create an uninitialized Task with no ID that will not be run
---This is used by the Task previewer (loading task bundles) so that we can use
---the Task rendering logic, but don't end up actually creating & registering a
---Task.
---@param opts overseer.TaskDefinition
---@return overseer.Task
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
    strategy_defn = opts.strategy,
    strategy = strategy.load(opts.strategy),
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

---@param opts overseer.TaskDefinition
---@return overseer.Task
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

  if self.strategy.render then
    self.strategy:render(lines, highlights, detail)
  end

  if detail > 1 and self.cmd then
    local cmd_str = type(self.cmd) == "string" and self.cmd or table.concat(self.cmd, " ")
    table.insert(lines, cmd_str)
  end

  -- Render components
  if detail >= 3 then
    for _, comp in ipairs(self.components) do
      if comp.desc then
        table.insert(lines, string.format("%s (%s)", comp.name, comp.desc))
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
---@return overseer.TaskDefinition
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
    strategy = self.strategy_defn,
    components = components,
  }
end

---@return overseer.Task
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
          if comp.on_dispose then
            comp:on_dispose(self)
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

---@param name string
---@return overseer.Component?
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

---@param name string
function Task:remove_component(name)
  vim.validate({
    name = { name, "s" },
  })
  return self:remove_components({ name })
end

---@param names string[]
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

---@param name string
function Task:has_component(name)
  vim.validate({ name = { name, "s" } })
  local new_comps = component.resolve({ name }, self.components)
  return vim.tbl_isempty(new_comps)
end

---@return boolean
function Task:is_pending()
  return self.status == STATUS.PENDING
end

---@return boolean
function Task:is_running()
  return self.status == STATUS.RUNNING
end

---@return boolean
function Task:is_complete()
  return self.status ~= STATUS.PENDING and self.status ~= STATUS.RUNNING
end

---@return boolean
function Task:is_disposed()
  return self.status == STATUS.DISPOSED
end

---@return number|nil
function Task:get_bufnr()
  return self.strategy:get_bufnr()
end

---@param soft boolean
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
    self:dispatch("on_status", self.status)
    local bufnr = self:get_bufnr()
    self.prev_bufnr = bufnr
    vim.defer_fn(function()
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        if util.is_bufnr_visible(bufnr) then
          vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
        else
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end, 1000)
    self.strategy:reset()
  end
  task_list.touch_task(self)
  self:dispatch("on_reset", soft)
end

---Dispatch an event to all other tasks
---@param name string
function Task:broadcast(name, ...)
  for _, task in ipairs(task_list.list_tasks()) do
    if task.id ~= self.id then
      task:dispatch(name, ...)
    end
  end
end

---Dispatch an event to all components
---@param name string
---@return any[]
function Task:dispatch(name, ...)
  local ret = {}
  for _, comp in ipairs(self.components) do
    if type(comp[name]) == "function" then
      local ok, err = pcall(comp[name], comp, self, ...)
      if not ok then
        log:error("Task %s dispatch %s.%s: %s", self.name, comp.name, name, err)
      elseif err ~= nil then
        table.insert(ret, err)
      end
    end
  end
  if self.id and not self:is_disposed() then
    task_list.update(self)
  end
  return ret
end

---@param status overseer.Status
function Task:finalize(status)
  vim.validate({
    status = { status, "s" },
  })
  if not self:is_running() then
    log:warn("Task %s cannot set status to %s: not running", self.name, status)
    return
  elseif status ~= STATUS.SUCCESS and status ~= STATUS.FAILURE and status ~= STATUS.CANCELED then
    log:error("Task %s finalize passed invalid status %s", self.name, status)
    return
  end
  self.status = status
  local results = self:dispatch("on_pre_result")
  if not vim.tbl_isempty(results) then
    self.result = vim.tbl_deep_extend("force", self.result or {}, unpack(results))
    self:dispatch("on_result", self.result)
  end
  self:dispatch("on_status", self.status)
  if self:is_complete() then
    self:dispatch("on_complete", status, self.result)
  end
end

---@param data? table
function Task:set_result(data)
  vim.validate({
    data = { data, "t" },
  })
  if not self:is_running() then
    return
  end
  self.result = data
  self:dispatch("on_result", self.result)
end

---Increment the refcount for this Task.
---Prevents it from being disposed
function Task:inc_reference()
  self._references = self._references + 1
end

---Decrement the refcount for this Task
function Task:dec_reference()
  self._references = self._references - 1
end

---Cleans up resources, removes from task list, and deletes buffer.
---@param force? boolean When true, will dispose even with a nonzero refcount or when buffer is visible
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
  local bufnr = self.strategy:get_bufnr()
  local bufnr_visible = util.is_bufnr_visible(bufnr)
  if not force then
    -- Can't dispose if the strategy bufnr is open
    if bufnr_visible then
      log:debug("Not disposing task %s: buffer is visible", self.name)
      return false
    end
  end
  if self:is_running() then
    if force then
      -- If we're forcing the dispose, remove the "restart after complete" component (if any),
      -- then stop, then dispose
      self:remove_component("on_complete_restart")
      self:stop()
    else
      error("Cannot call dispose on running task")
    end
  end
  self.status = STATUS.DISPOSED
  self:dispatch("on_status", self.status)
  log:debug("Disposing task %s", self.name)
  self.strategy:dispose()
  self:dispatch("on_dispose")
  task_list.remove(self)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    if bufnr_visible then
      vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    else
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
  return true
end

---@param force_stop? boolean If true, restart the Task even if it is currently running
---@return boolean
function Task:restart(force_stop)
  vim.validate({ force_stop = { force_stop, "b", true } })
  log:debug("Restart task %s", self.name)
  if self:is_running() then
    if force_stop then
      self:stop()
    else
      return false
    end
  end

  self:reset(false)
  self:start()
  return true
end

---Called when the task strategy exits
---@param code number
function Task:on_exit(code)
  self.exit_code = code
  if not self:is_running() then
    -- We've already finalized, so we probably canceled this task
    return
  end
  self:dispatch("on_exit", code)
  -- We shouldn't hit this unless there is no result component or it errored
  if self:is_running() then
    log:error(
      "Task %s did not finalize during exit. Is it missing the on_exit_set_status component?",
      self.name
    )
    self:set_result({ error = "Task did not finalize during exit" })
    self:finalize(STATUS.FAILURE)
  end
end

function Task:start()
  if self:is_complete() then
    log:error("Cannot start task '%s' that has completed", self.name)
    return false
  end
  if self:is_disposed() then
    log:error("Cannot start task '%s' that has been disposed", self.name)
    return false
  end
  if self:is_running() then
    return false
  end
  if vim.tbl_contains(self:dispatch("on_pre_start"), false) then
    log:debug("Component prevented task %s from starting", self.name)
    return false
  end
  log:debug("Starting task %s", self.name)
  local ok, err = pcall(self.strategy.start, self.strategy, self)
  if not ok then
    log:error("Strategy '%s' failed to start for task '%s': %s", self.strategy.name, self.name, err)
    return false
  end
  self.status = STATUS.RUNNING
  self:dispatch("on_status", self.status)
  self:dispatch("on_start")
  local bufnr = self.strategy:get_bufnr()
  if bufnr then
    vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
  end

  -- If this task's previous buffer was open in any wins, replace it
  if bufnr and self.prev_bufnr then
    local prev_bufnr = self.prev_bufnr
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == prev_bufnr then
        -- If stickybuf is installed, make sure it doesn't interfere
        pcall(vim.api.nvim_win_del_var, win, "sticky_original_bufnr")
        pcall(vim.api.nvim_win_del_var, win, "sticky_bufnr")
        pcall(vim.api.nvim_win_del_var, win, "sticky_buftype")
        pcall(vim.api.nvim_win_del_var, win, "sticky_filetype")
        vim.api.nvim_win_set_buf(win, bufnr)
      end
    end
  end
  return true
end

function Task:stop()
  if not self:is_running() then
    return false
  end
  log:debug("Stopping task %s", self.name)
  self:finalize(STATUS.CANCELED)
  self.strategy:stop()
  return true
end

return Task
