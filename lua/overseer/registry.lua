local M = {}

local callbacks = {}

M.tasks = {}

local lookup = {}

local function on_update()
  local to_remove = {}
  for i, cb in ipairs(callbacks) do
    if not cb() then
      table.insert(to_remove, i)
    end
  end
  for i = #to_remove, 1, -1 do
    table.remove(callbacks, to_remove[i])
  end
end

M.update_task = function(task)
  if not lookup[task.id] then
    lookup[task.id] = task
    table.insert(M.tasks, task)
  end
  on_update()
end

M.remove_task = function(task)
  lookup[task.id] = nil
  for i, t in ipairs(M.tasks) do
    if t.id == task.id then
      table.remove(M.tasks, i)
      break
    end
  end
  on_update()
end

M.add_view = function(view)
  table.insert(callbacks, function()
    return view:render(M.tasks)
  end)
  view:render(M.tasks)
end

M.add_update_callback = function(cb)
  table.insert(callbacks, cb)
end

M.get_by_name = function(name)
  for _, task in ipairs(M.tasks) do
    if task.name == name then
      return task
    end
  end
end

return M
