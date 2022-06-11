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
  rerender()
end

M.serialize_tasks = function()
  local ret = {}
  for _, task in ipairs(tasks) do
    if task:is_serializable() then
      table.insert(ret, task:serialize())
    end
  end
  return ret
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

M.get_by_name = function(name)
  for _, task in ipairs(tasks) do
    if task.name == name then
      return task
    end
  end
end

-- 1-indexed, most recent first
M.get_by_index = function(index)
  return tasks[#tasks + 1 - index]
end

M.list_tasks = function(opts)
  opts = opts or {}
  vim.validate({
    unique = { opts.unique, "b", true },
    -- name is string or list
    name_not = { opts.name_not, "b", true },
    -- status is string or list
    status_not = { opts.name_not, "b", true },
    recent_first = { opts.recent_first, "b", true },
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
      and (not opts.unique or not seen[task.name])
    then
      seen[task.name] = true
      table.insert(ret, task)
    end
  end
  if opts.recent_first then
    util.tbl_reverse(ret)
  end
  return ret
end

return M
