local constants = require("overseer.constants")
local log = require("overseer.log")
local task_list = require("overseer.task_list")
local STATUS = constants.STATUS

return {
  desc = "Run another task on status change",
  params = {
    task_id = {
      desc = "Id of the task template to trigger",
      type = "integer",
    },
    once = {
      desc = "When true, only trigger task once then remove this component",
      type = "boolean",
      default = true,
    },
  },
  serializable = false,
  constructor = function(params)
    return {
      on_status = function(self, task)
        if task.status ~= STATUS.SUCCESS then
          return
        end
        local next = task_list.get(params.task_id)
        if next then
          next:dispatch("on_dependency_complete", task.id)
        else
          log:warn("Could not find task %s", params.task_id)
        end
        if params.once then
          vim.defer_fn(function()
            task:remove_component("vscode.on_status_start_task")
          end, 1)
        end
      end,
    }
  end,
}
