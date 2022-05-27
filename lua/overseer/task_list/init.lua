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
  if task.disposed then
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
  print(string.format("Resetting %s", task.id))
  table.remove(tasks, idx)
  table.insert(tasks, task)
  rerender()
end

M.serialize_tasks = function()
  local ret = {}
  for _, task in ipairs(tasks) do
    table.insert(ret, task:serialize())
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

-- List tasks, unique by name
M.list_unique_tasks = function()
  local ret = {}
  local seen = {}
  for i = #tasks, 1, -1 do
    local task = tasks[i]
    if not seen[task.name] then
      seen[task.name] = true
      table.insert(ret, task)
    end
  end
  return ret
end

return M
