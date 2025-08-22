local constants = require("overseer.constants")
local log = require("overseer.log")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local STATUS = constants.STATUS

---@type overseer.ComponentFileDefinition
return {
  desc = "Set dependencies for task",
  params = {
    tasks = {
      desc = "Names of dependency task templates",
      long_desc = 'This can be a list of strings (template names, e.g. "cargo build"), tables (template name with params, e.g. {"mytask", foo = "bar"}), or tables (raw task params, e.g. {cmd = "sleep 10"})',
      -- TODO Can't input dependencies WITH params in the task launcher b/c the type is too complex
      type = "list",
      optional = true,
    },
    task_names = {
      deprecated = true,
      desc = "Names of dependency task templates",
      long_desc = 'This can be a list of strings (template names, e.g. "cargo build"), tables (template name with params, e.g. {"mytask", foo = "bar"}), or tables (raw task params, e.g. {cmd = "sleep 10"})',
      -- TODO Can't input dependencies WITH params in the task launcher b/c the type is too complex
      type = "list",
      optional = true,
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
        for i, name_or_config in ipairs(params.tasks or params.task_names or {}) do
          local task_id = self.task_lookup[i]
          local dep_task = task_id and task_list.get(task_id)
          if not dep_task then
            -- If no task ID found, start the dependency
            util.run_template_or_task(name_or_config, function(new_task)
              if not new_task then
                log.error(
                  "Task(%s)[dependencies] could not find template %s",
                  task.name,
                  name_or_config
                )
                return
              end
              new_task.cwd = new_task.cwd or task.cwd
              new_task.env = new_task.env or task.env
              new_task.parent_id = task.parent_id or task.id
              self.task_lookup[i] = new_task.id
              new_task:add_component({
                "dependencies.on_success_complete_dependency",
                task_id = task.id,
              })
              new_task.ephemeral = true
              new_task:start()
            end)
            started_any = true
            if params.sequential then
              return false
            end
          else
            if dep_task.status == STATUS.PENDING then
              dep_task:start()
              started_any = true
              if params.sequential then
                return false
              end
            elseif dep_task.status ~= STATUS.SUCCESS then
              return false
            end
          end
        end
        return not started_any
      end,
      on_reset = function(self, task)
        for _, task_id in pairs(self.task_lookup) do
          local dep_task = task_list.get(task_id)
          if dep_task then
            dep_task:reset()
          end
        end
      end,
      on_dispose = function(self, task)
        for _, task_id in pairs(self.task_lookup) do
          local dep_task = task_list.get(task_id)
          if dep_task then
            dep_task:stop()
            dep_task:dispose(true)
          end
        end
      end,
      on_dependency_complete = function(self, task)
        task:start()
      end,
    }
  end,
}
