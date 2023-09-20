local util = require("overseer.util")
local M = {}

local tasks = {}
local lookup = {}

M.get_or_create_bufnr = function()
  local sidebar, created = require("overseer.task_list.sidebar").get_or_create()
  if created then
    sidebar:render(tasks)
  end
  return sidebar.bufnr
end

local function rerender()
  local sidebar = require("overseer.task_list.sidebar")
  local sb = sidebar.get()
  if sb then
    sb:render(tasks)
  end
end

M.rerender = rerender

local function group_parents_and_children()
  local order = {}
  for i, task in ipairs(tasks) do
    order[task.id] = i
  end
  for _, task in ipairs(tasks) do
    if task.parent_id then
      order[task.id] = order[task.parent_id] - 0.5
    end
  end
  table.sort(tasks, function(a, b)
    return order[a.id] < order[b.id]
  end)
end

M.update = function(task)
  if not task then
    rerender()
    return
  end
  if task:is_disposed() then
    return
  end
  if not lookup[task.id] then
    lookup[task.id] = task
    table.insert(tasks, task)
    group_parents_and_children()
  end
  rerender()
end

M.touch_task = function(task)
  if not lookup[task.id] then
    return
  end
  local idx = util.tbl_index(tasks, task.id, function(t)
    return t.id
  end)
  table.remove(tasks, idx)
  table.insert(tasks, task)
  group_parents_and_children()
  rerender()
end

M.remove = function(task)
  lookup[task.id] = nil
  for i, t in ipairs(tasks) do
    if t.id == task.id then
      table.remove(tasks, i)
      break
    end
  end
  rerender()
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

-- 1-indexed, most recent first
---@param index number
---@return overseer.Task|nil
M.get_by_index = function(index)
  return tasks[#tasks + 1 - index]
end

---@class overseer.ListTaskOpts
---@field unique? boolean Deduplicates non-running tasks by name
---@field name? string|string[] Only list tasks with this name or names
---@field name_not? boolean Invert the name search (tasks *without* that name)
---@field status? overseer.Status|overseer.Status[] Only list tasks with this status or statuses
---@field status_not? boolean Invert the status search
---@field recent_first? boolean The most recent tasks are first in the list
---@field bundleable? boolean Only list tasks that should be included in a bundle
---@field filter? fun(task: overseer.Task): boolean

---@param opts? overseer.ListTaskOpts
---@return overseer.Task[]
M.list_tasks = function(opts)
  opts = opts or {}
  vim.validate({
    unique = { opts.unique, "b", true },
    -- name is string or list
    name_not = { opts.name_not, "b", true },
    -- status is string or list
    status_not = { opts.status_not, "b", true },
    recent_first = { opts.recent_first, "b", true },
    bundleable = { opts.bundleable, "b", true },
    filter = { opts.filter, "f", true },
  })
  local name = util.list_to_map(opts.name or {})
  local status = util.list_to_map(opts.status or {})
  local seen = {}
  local ret = {}
  for _, task in ipairs(tasks) do
    if
      (
        not opts.name
        or (name[task.name] and not opts.name_not)
        or (not name[task.name] and opts.name_not)
      )
      and (not opts.status or (status[task.status] and not opts.status_not) or (not status[task.status] and opts.status_not))
      and (not opts.bundleable or task:should_include_in_bundle())
      and (not opts.filter or opts.filter(task))
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
  if opts.recent_first then
    util.tbl_reverse(ret)
  end
  return ret
end

return M
