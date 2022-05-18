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

M.add_update_callback = function(cb)
  table.insert(callbacks, cb)
end

return M
