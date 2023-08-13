---@type overseer.ComponentFileDefinition
local comp = {
  desc = "Listens for task status broadcasts and updates orchestration tasks",
  params = {},
  constructor = function()
    return {
      on_other_task_status = function(self, task, other_task)
        if task.strategy.name == "orchestrator" then
          task.strategy:start_next()
        end
      end,
    }
  end,
}

return comp
