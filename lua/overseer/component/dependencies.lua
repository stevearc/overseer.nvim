local commands = require("overseer.commands")
local constants = require("overseer.constants")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local STATUS = constants.STATUS

return {
  desc = "Set dependencies for task",
  params = {
    task_names = {
      desc = "Names of dependency task templates",
      long_desc = 'This can be a list of strings (template names) or tables (name with params, e.g. {"shell", cmd = "sleep 10"})',
      -- TODO Can't input dependencies WITH params in the task launcher b/c the type is too complex
      type = "list",
    },
    sequential = {
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    return {
      task_lookup = {},
      on_pre_start = function(self, task)
        local started_any = false
        for _, name_or_config in ipairs(params.task_names) do
          local name, dep_params = util.split_config(name_or_config)
          local task_id = self.task_lookup[name]
          local dep_task = task_id and task_list.get(task_id)
          if not dep_task then
            -- If no task ID found, start the dependency
            commands.run_template({
              name = name,
              params = dep_params,
              autostart = false,
              cwd = task.cwd,
              env = task.env,
            }, function(new_task)
              if not new_task then
                return
              end
              self.task_lookup[name] = new_task.id
              new_task:add_component({ "on_success_complete_dependency", task_id = task.id })
              new_task:start()
            end)
            started_any = true
            if params.sequential then
              return false
            end
          else
            if dep_task.status ~= STATUS.SUCCESS then
              return false
            end
          end
        end
        return not started_any
      end,
      on_dependency_complete = function(self, task)
        task:start()
      end,
    }
  end,
}
