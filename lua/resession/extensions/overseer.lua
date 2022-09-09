local overseer = require("overseer")
return {
  on_save = function()
    local task_list = require("overseer.task_list")
    return task_list.serialize_tasks()
  end,
  on_load = function(data)
    for _, params in ipairs(data) do
      local task = overseer.new_task(params)
      task:start()
    end
  end,
}
