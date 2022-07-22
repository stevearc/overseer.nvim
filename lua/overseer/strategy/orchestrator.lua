-- This is a run strategy for "meta" tasks. This task itself will not perform
-- any jobs, but will instead wrap and manage a collection of other tasks.
local commands = require("overseer.commands")
local constants = require("overseer.constants")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local STATUS = constants.STATUS

---@param items table
---@param cb fun(item: any)
local function for_each(items, cb)
  for _, sub in ipairs(items) do
    if type(sub) == "table" and vim.tbl_islist(sub) then
      for_each(sub, cb)
    else
      cb(sub)
    end
  end
end

---@param tasks table
---@param cb fun(task: overseer.Task)
local function for_each_task(tasks, cb)
  for_each(tasks, function(id)
    local task = task_list.get(id)
    if task then
      cb(task)
    end
  end)
end

local OrchestratorStrategy = {}

---@return overseer.Strategy
function OrchestratorStrategy.new(opts)
  vim.validate({
    opts = { opts, "t" },
  })
  vim.validate({
    tasks = { opts.tasks, "t" },
  })
  return setmetatable({
    task = nil,
    bufnr = vim.api.nvim_create_buf(false, true),
    task_defns = opts.tasks,
    tasks = {},
  }, { __index = OrchestratorStrategy })
end

function OrchestratorStrategy:render_buf()
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    return
  end
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)

  local lines = {}
  local highlights = {}

  local columns = {}
  local col_widths = {}
  local max_row = 0

  local function calc_width(task)
    return vim.api.nvim_strwidth(task.name) + task.status:len() + 1
  end

  for i, tasks in ipairs(self.tasks) do
    if vim.tbl_islist(tasks) then
      columns[i] = tasks
    else
      columns[i] = { tasks }
    end
    columns[i] = vim.tbl_map(function(id)
      return task_list.get(id)
    end, columns[i])
    col_widths[i] = 1
    for _, task in ipairs(columns[i]) do
      col_widths[i] = math.max(col_widths[i], calc_width(task))
    end
    max_row = math.max(max_row, #columns[i])
  end

  for i = 1, max_row do
    local line = {}
    local col_start = 0
    for j, column in ipairs(columns) do
      local task = column[i]
      if task then
        table.insert(
          line,
          util.ljust(string.format("%s %s", task.status, task.name), col_widths[j])
        )
        local col_end = col_start + task.status:len()
        table.insert(
          highlights,
          { string.format("Overseer%s", task.status), #lines + 1, col_start, col_end }
        )
        col_start = col_start + line[#line]:len() + 4
      end
    end
    table.insert(lines, table.concat(line, " -> "))
  end

  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(self.bufnr, "modified", false)
  util.add_highlights(self.bufnr, ns, highlights)
end

function OrchestratorStrategy:reset()
  self.task = nil
  for_each_task(self.tasks, function(task)
    task:reset(false)
  end)
end

function OrchestratorStrategy:get_bufnr()
  return self.bufnr
end

local function get_status(task_or_list)
  if type(task_or_list) == "table" and vim.tbl_islist(task_or_list) then
    for _, v in ipairs(task_or_list) do
      local status = get_status(v)
      if status ~= STATUS.SUCCESS then
        return status
      end
    end
    return STATUS.SUCCESS
  else
    local task = task_list.get(task_or_list)
    return task and task.status or STATUS.FAILURE
  end
end

function OrchestratorStrategy:start_tasks(task_or_list)
  if type(task_or_list) == "table" and vim.tbl_islist(task_or_list) then
    for _, v in ipairs(task_or_list) do
      self:start_tasks(v)
    end
  else
    local task = task_list.get(task_or_list)
    if task then
      task:start()
    end
  end
end

function OrchestratorStrategy:start_next()
  if not self.task or self.task:is_disposed() then
    return
  end
  for _, section in ipairs(self.tasks) do
    local status = get_status(section)
    if status == STATUS.PENDING then
      self:start_tasks(section)
      self:render_buf()
      return
    elseif status == STATUS.RUNNING then
      self:render_buf()
      return
    elseif status == STATUS.FAILURE or status == STATUS.CANCELED then
      if self.task and self.task:is_running() then
        self.task:finalize(status)
      end
      self:render_buf()
      return
    end
  end
  self.task:finalize(STATUS.SUCCESS)
  self:render_buf()
end

---@param tasks table
---@param task_defns table
function OrchestratorStrategy:_start_task_list(tasks, task_defns)
  local task_count = 0
  for_each(task_defns, function()
    task_count = task_count + 1
  end)
  local count = 0
  for i, def in ipairs(task_defns) do
    if type(def) == "table" and vim.tbl_islist(def) then
      tasks[i] = tasks[i] or {}
      self:_start_task_list(tasks[i], def)
    else
      local idx = i
      local name, params = util.split_config(def)
      local task = tasks[i] and task_list.get(tasks[i])
      if task then
        task:start()
      else
        tasks[i] = -1
        commands.run_template({ name = name, nostart = true, params = params }, function(new_task)
          if not new_task then
            return
          end
          new_task:add_component("on_status_broadcast")
          tasks[idx] = new_task.id
          count = count + 1
          if count == task_count then
            self:start_next()
          end
        end)
      end
    end
  end
end

---@param task overseer.Task
function OrchestratorStrategy:start(task)
  self.task = task
  task:add_component("on_broadcast_update_orchestrator")
  self:_start_task_list(self.tasks, self.task_defns)
end

function OrchestratorStrategy:stop()
  for_each_task(self.tasks, function(task)
    task:stop()
  end)
end

function OrchestratorStrategy:dispose()
  for_each_task(self.tasks, function(task)
    task:dispose()
  end)
end

return OrchestratorStrategy
