local util = require("overseer.util")
local M = {}

---@type overseer.Task[]
local tasks = {}
---@type table<integer, overseer.Task>
local lookup = {}
---@type table<function, overseer.Task[]>
local sorted_cache = {}

---@return integer
M.get_or_create_bufnr = function()
  local sidebar = require("overseer.task_list.sidebar").get_or_create()
  return sidebar.bufnr
end

local function dispatch()
  sorted_cache = {}
  vim.api.nvim_exec_autocmds("User", { pattern = "OverseerListUpdate", modeline = false })
end

---@param sort? fun(a: overseer.Task, b: overseer.Task): boolean Function that sorts tasks
local function get_sorted_tasks(sort)
  if not sort then
    sort = M.sort_newest_first
  end
  if sorted_cache[sort] then
    return sorted_cache[sort]
  end

  local child_groups = {}
  local top_level = {}
  for _, task in ipairs(tasks) do
    if task.parent_id then
      local group = child_groups[task.parent_id]
      if not group then
        group = {}
        child_groups[task.parent_id] = group
      end
      table.insert(group, task)
    else
      table.insert(top_level, task)
    end
  end

  table.sort(top_level, sort)
  for _, children in pairs(child_groups) do
    table.sort(children, sort)
  end

  local ret = {}
  for _, task in ipairs(top_level) do
    table.insert(ret, task)
    local children = child_groups[task.id]
    if children then
      for _, child in ipairs(children) do
        table.insert(ret, child)
      end
    end
  end

  sorted_cache[sort] = ret
  return ret
end

---Trigger a re-render without re-sorting the tasks
---@param task? overseer.Task
M.touch = function(task)
  if not task or task:is_disposed() then
    return
  end
  if not lookup[task.id] then
    lookup[task.id] = task
    table.insert(tasks, task)
  end
  dispatch()
end

M.on_task_updated = function()
  dispatch()
end

---@param task overseer.Task
M.remove = function(task)
  lookup[task.id] = nil
  for i, t in ipairs(tasks) do
    if t.id == task.id then
      table.remove(tasks, i)
      break
    end
  end
  dispatch()
end

---@param id number
---@return overseer.Task|nil
M.get = function(id)
  return lookup[id]
end

---@param name string
---@return overseer.Task|nil
M.get_by_name = function(name)
  for _, task in ipairs(tasks) do
    if task.name == name then
      return task
    end
  end
end

---@class (exact) overseer.ListTaskOpts
---@field unique? boolean Deduplicates non-running tasks by name
---@field status? overseer.Status|overseer.Status[] Only list tasks with this status or statuses
---@field include_ephemeral? boolean Include ephemeral tasks
---@field wrapped? boolean Include tasks that were created by the jobstart/vim.system wrappers
---@field filter? fun(task: overseer.Task): boolean Only include tasks where this function returns true
---@field sort? fun(a: overseer.Task, b: overseer.Task): boolean Function that sorts tasks

---@param opts? overseer.ListTaskOpts
---@return overseer.Task[]
M.list_tasks = function(opts)
  opts = opts or {}
  vim.validate("unique", opts.unique, "boolean", true)
  vim.validate("status", opts.status, function(n)
    return type(n) == "string" or type(n) == "table"
  end, true)
  vim.validate("wrapped", opts.wrapped, "boolean", true)
  vim.validate("include_ephemeral", opts.include_ephemeral, "boolean", true)
  vim.validate("filter", opts.filter, "function", true)
  vim.validate("sort", opts.sort, "function", true)

  local status = util.list_to_map(opts.status or {})
  local seen = {}
  local ret = {}
  for _, task in ipairs(get_sorted_tasks(opts.sort)) do
    if
      (not opts.status or status[task.status])
      and (opts.include_ephemeral or not task.ephemeral)
      and (not opts.filter or opts.filter(task))
      and (opts.wrapped or not task.source)
    then
      local idx = seen[task.name]
      if idx and opts.unique then
        local prev = ret[idx]
        if prev:is_running() and task:is_running() then
          -- If both tasks are running, do not apply uniqueness
          table.insert(ret, task)
        elseif not prev:is_running() then
          -- If the prev task is not running, overwrite it
          ret[idx] = task
        end
      else
        table.insert(ret, task)
        seen[task.name] = #ret
      end
    end
  end
  return ret
end

---General purpose sort by status and start/end time
---@param a overseer.Task
---@param b overseer.Task
---@return boolean
M.default_sort = function(a, b)
  if (a.time_end == nil) ~= (b.time_end == nil) then
    -- If only one of the tasks has already ended, put the other one first
    return a.time_end == nil
  elseif (a.time_start ~= nil) ~= (b.time_start ~= nil) then
    -- If only one of the tasks has started, put the other one first
    return a.time_start == nil
  elseif a.time_end ~= nil and a.time_end ~= b.time_end then
    -- If both tasks have ended, sort by end time (most recent first)
    return a.time_end > b.time_end
  elseif a.time_start ~= nil and a.time_start ~= b.time_start then
    -- If both tasks have started, sort by start time (most recent first)
    return a.time_start > b.time_start
  end

  -- fall back to sort by name
  return a.name < b.name
end

---A sort function that puts the newest tasks first
---@param a overseer.Task
---@param b overseer.Task
---@return boolean
M.sort_newest_first = function(a, b)
  if a.time_start == nil then
    if b.time_start == nil then
      -- fall back to sort by name
      return a.name < b.name
    else
      return true
    end
  elseif b.time_start == nil then
    return false
  end

  -- Sort newest first
  return a.time_start > b.time_start
end

---A sort function that puts tasks that finished most recently first
---@param a overseer.Task
---@param b overseer.Task
---@return boolean
M.sort_finished_recently = function(a, b)
  if (a.time_end == nil) ~= (b.time_end == nil) then
    return a.time_end ~= nil
  elseif a.time_end ~= nil and a.time_end ~= b.time_end then
    return a.time_end > b.time_end
  elseif (a.time_start == nil) ~= (b.time_start == nil) then
    return a.time_start ~= nil
  elseif a.time_start ~= nil and a.time_start ~= b.time_start then
    return a.time_start > b.time_start
  else
    -- fall back to sort by name
    return a.name < b.name
  end
end

return M
