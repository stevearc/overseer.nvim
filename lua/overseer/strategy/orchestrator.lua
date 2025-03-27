-- This is a run strategy for "meta" tasks. This task itself will not perform
-- any jobs, but will instead wrap and manage a collection of other tasks.
local Task = require("overseer.task")
local constants = require("overseer.constants")
local log = require("overseer.log")
local task_list = require("overseer.task_list")
local template = require("overseer.template")
local util = require("overseer.util")
local STATUS = constants.STATUS
---@diagnostic disable-next-line: deprecated
local islist = vim.isarray or vim.tbl_islist

---Check if this is a reference to a defined task template
---@param task any
---@return boolean
local function is_named_task(task)
  -- This can either be a task name, or a table with a task name as the first element
  if type(task) == "string" then
    return true
  end
  assert(type(task) == "table", "Task must be a string or table")

  if islist(task) then
    -- If this is a list-like table, then this is not a named task.
    -- It will be a list of named tasks or task definitions.
    return false
  elseif type(task[1]) == "string" then
    -- Named tasks have their name as the first element
    return true
  else
    -- This is a task definition
    return false
  end
end

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

---@class overseer.OrchestratorStrategy : overseer.Strategy
---@field bufnr integer
---@field task_defns table[][]
---@field tasks integer[][]
local OrchestratorStrategy = {}

---Strategy for a meta-task that manage a sequence of other tasks
---@param opts table
---    tasks table A list of task definitions to run. Can include sub-lists that will be run in parallel
---@return overseer.Strategy
---@example
--- overseer.new_task({
---   name = "Build and serve app",
---   strategy = {
---     "orchestrator",
---     tasks = {
---       "make clean", -- Step 1: clean
---       {             -- Step 2: build js and css in parallel
---          "npm build",
---         { cmd = {"lessc", "styles.less", "styles.css"} },
---       },
---       "npm serve",  -- Step 3: serve
---     },
---   },
--- })
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
    if is_named_task(v) then
      task_defns[i] = { v }
    elseif islist(v) then
      task_defns[i] = v
    else
      task_defns[i] = { v }
    end
  end
  local strategy = {
    task = nil,
    bufnr = vim.api.nvim_create_buf(false, true),
    task_defns = task_defns,
    tasks = {},
  }
  setmetatable(strategy, { __index = OrchestratorStrategy })
  ---@type overseer.OrchestratorStrategy
  return strategy
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

  vim.bo[self.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  vim.bo[self.bufnr].modifiable = false
  vim.bo[self.bufnr].modified = false
  util.add_highlights(self.bufnr, ns, highlights)
end

function OrchestratorStrategy:reset()
  self.task = nil
  for_each_task(self.tasks, function(task)
    task:reset()
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
    local all_success = true
    for i, section in ipairs(self.tasks) do
      all_success = false
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

---@private
---@param defn table
---@param i integer First index into the tasks table
---@param j integer Second index into the tasks table
function OrchestratorStrategy:build_task(defn, i, j)
  local search = {
    dir = self.task.cwd,
  }
  self.tasks[i][j] = -1

  ---@param task overseer.Task
  local function finalize_subtask(task)
    task:add_component("orchestrator.on_status_broadcast")
    -- Don't include child tasks when saving to bundle. We will re-create them when the
    -- orchestration task is loaded.
    task:set_include_in_bundle(false)
    self.tasks[i][j] = task.id
    if self:section_complete(1) then
      self:start_next()
    end
  end

  if type(defn) == "table" and defn[1] == nil then
    defn = vim.tbl_extend("error", { parent_id = self.task.id }, defn)
    ---@cast defn overseer.TaskDefinition
    local task = require("overseer").new_task(defn)
    finalize_subtask(task)
    return
  end

  local name, params = util.split_config(defn)
  params = params or {}
  template.get_by_name(name, search, function(tmpl)
    if not tmpl then
      log.error("Orchestrator could not find task '%s'", name)
      self.task:finalize(STATUS.FAILURE)
      return
    end
    local build_opts = {
      search = search,
      params = params,
    }
    template.build_task_args(
      tmpl,
      build_opts,
      vim.schedule_wrap(function(task_defn)
        if not task_defn then
          log.warn("Canceled building task '%s'", name)
          self.task:finalize(STATUS.FAILURE)
          return
        end
        if params.cwd then
          task_defn.cwd = params.cwd
        end
        if task_defn.env or params.env then
          task_defn.env = vim.tbl_deep_extend("force", task_defn.env or {}, params.env or {})
        end
        task_defn.parent_id = self.task.id
        local new_task = Task.new(task_defn)
        finalize_subtask(new_task)
      end)
    )
  end)
end

---Check if we have fully created all of the tasks in a section
---@private
---@param idx integer
function OrchestratorStrategy:section_complete(idx)
  if self.task_defns[idx] == nil then
    return true
  end
  for _, v in ipairs(self.tasks[idx]) do
    if v == -1 then
      return false
    end
  end
  return vim.tbl_count(self.tasks[idx]) == vim.tbl_count(self.task_defns[idx])
end

---@param task overseer.Task
function OrchestratorStrategy:start(task)
  self.task = task
  task:add_component("orchestrator.on_broadcast_update_orchestrator")
  for i, section in ipairs(self.task_defns) do
    self.tasks[i] = self.tasks[i] or {}
    for j, def in ipairs(section) do
      local subtask = self.tasks[i][j] and task_list.get(self.tasks[i][j])
      if not subtask or subtask:is_disposed() then
        self:build_task(def, i, j)
      end
    end
  end

  if self:section_complete(1) then
    vim.schedule(function()
      self:start_next()
    end)
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
  util.soft_delete_buf(self.bufnr)
end

return OrchestratorStrategy
