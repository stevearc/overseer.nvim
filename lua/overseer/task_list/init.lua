local M = {}

local tasks = {}
local lookup = {}

M.get_or_create_bufnr = function()
  local sidebar = require("overseer.task_list.sidebar")
  return sidebar.get_or_create().bufnr
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
  for _, task in ipairs(M.tasks) do
    if task.name == name then
      return task
    end
  end
end

-- 1-indexed, most recent first
M.get_by_index = function(index)
  return M.tasks[#M.tasks + 1 - index]
end

-- List tasks, unique by name
M.list_unique_tasks = function()
  local ret = {}
  local seen = {}
  for i = #M.tasks, 1, -1 do
    local task = M.tasks[i]
    if not seen[task.name] then
      seen[task.name] = true
      table.insert(ret, task)
    end
  end
  return ret
end

return M
