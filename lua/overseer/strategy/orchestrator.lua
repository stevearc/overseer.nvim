-- This is a run strategy for "meta" tasks. This task itself will not perform
-- any jobs, but will instead wrap and manage a collection of other tasks.
local commands = require("overseer.commands")
local constants = require("overseer.constants")
local log = require("overseer.log")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local STATUS = constants.STATUS

---@param tasks table
---@param cb fun(task: overseer.Task)
local function for_each_task(tasks, cb)
  for _, section in ipairs(tasks) do
    for _, id in ipairs(section) do
      local task = task_list.get(id)
      if task then
        cb(task)
      end
    end
  end
end

---@class overseer.OrchestratorStrategy
---@field bufnr integer
---@field task_defns overseer.Serialized[][]
---@field tasks integer[][]
local OrchestratorStrategy = {}

---@return overseer.Strategy
function OrchestratorStrategy.new(opts)
  vim.validate({
    opts = { opts, "t" },
  })
  vim.validate({
    tasks = { opts.tasks, "t" },
  })
  -- Each entry in tasks can be either a task definition, OR a list of task definitions.
  -- Convert it to each entry being a list of task definitions.
  local task_defns = {}
  for i, v in ipairs(opts.tasks) do
    if type(v) == "table" and vim.tbl_islist(v) then
      task_defns[i] = v
    else
      task_defns[i] = { v }
    end
  end
  return setmetatable({
    task = nil,
    bufnr = vim.api.nvim_create_buf(false, true),
    task_defns = task_defns,
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

  for i, task_ids in ipairs(self.tasks) do
    columns[i] = vim.tbl_map(task_list.get, task_ids)
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
      else
        table.insert(line, string.rep(" ", col_widths[j]))
      end
      col_start = col_start + line[#line]:len() + 4
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

---@param task_ids integer[]
local function get_status(task_ids)
  for _, v in ipairs(task_ids) do
    local task = task_list.get(v)
    local status = task and task.status or STATUS.FAILURE
    if status ~= STATUS.SUCCESS then
      return status
    end
  end
  return STATUS.SUCCESS
end

function OrchestratorStrategy:start_next()
  if self.task and not self.task:is_complete() then
    local all_success = false
    for i, section in ipairs(self.tasks) do
      local status = get_status(section)
      if status == STATUS.PENDING then
        for _, id in ipairs(section) do
          local task = task_list.get(id)
          if task and task:is_pending() then
            task:start()
          end
        end
        break
      elseif status == STATUS.RUNNING then
        break
      elseif status == STATUS.FAILURE or status == STATUS.CANCELED then
        if self.task and self.task:is_running() then
          self.task:finalize(status)
        end
        break
      end
      all_success = i == #self.tasks
    end
    if all_success then
      self.task:finalize(STATUS.SUCCESS)
    end
  end
  self:render_buf()
end

---@param task overseer.Task
function OrchestratorStrategy:start(task)
  self.task = task
  task:add_component("orchestrator.on_broadcast_update_orchestrator")
  local function section_complete(idx)
    for _, v in ipairs(self.tasks[idx]) do
      if v == -1 then
        return false
      end
    end
    return vim.tbl_count(self.tasks[idx]) == vim.tbl_count(self.task_defns[idx])
  end
  for i, section in ipairs(self.task_defns) do
    self.tasks[i] = self.tasks[i] or {}
    for j, def in ipairs(section) do
      local task_idx = { i, j }
      local name, params = util.split_config(def)
      local subtask = self.tasks[i][j] and task_list.get(self.tasks[i][j])
      if not subtask or subtask:is_disposed() then
        self.tasks[i][j] = -1
        commands.run_template(
          { name = name, autostart = false, params = params },
          vim.schedule_wrap(function(new_task, err)
            if not new_task then
              log:error("Orchestrator could not start task '%s': %s", name, err)
              self.task:finalize(STATUS.FAILURE)
              return
            end
            new_task:add_component("orchestrator.on_status_broadcast")
            self.tasks[task_idx[1]][task_idx[2]] = new_task.id
            if section_complete(1) then
              self:start_next()
            end
          end)
        )
      end
    end
  end
  if section_complete(1) then
    self:start_next()
  end
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
