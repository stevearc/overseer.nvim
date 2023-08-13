local constants = require("overseer.constants")
local log = require("overseer.log")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local STATUS = constants.STATUS

---@type overseer.ComponentFileDefinition
local comp = {
  desc = "Run other tasks after this task completes",
  params = {
    task_names = {
      desc = "Names of dependency task templates",
      long_desc = 'This can be a list of strings (template names, e.g. {"cargo build"}), tables (name with params, e.g. {"shell", cmd = "sleep 10"}), or tables (raw task params, e.g. {cmd = "sleep 10"})',
      -- TODO Can't input dependencies WITH params in the task launcher b/c the type is too complex
      type = "list",
    },
    statuses = {
      desc = "Only run successive tasks if the final status is in this list",
      type = "list",
      default = { STATUS.SUCCESS },
      subtype = {
        type = "enum",
        choices = STATUS.values,
      },
    },
    detach = {
      desc = "Tasks created will not be linked to the parent task",
      long_desc = "This means they will not restart when the parent restarts, and will not be disposed when the parent is disposed",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    return {
      task_lookup = {},
      all_tasks = {},
      on_complete = function(self, task)
        if not vim.tbl_contains(params.statuses, task.status) then
          return
        end
        for i, name_or_config in ipairs(params.task_names) do
          local task_id = self.task_lookup[i]
          local after_task = task_id and task_list.get(task_id)
          if after_task then
            if not after_task:is_pending() then
              after_task:reset()
            end
            after_task:start()
          else
            util.run_template_or_task(name_or_config, function(new_task)
              if not new_task then
                log:error(
                  "Task(%s)[run_after] could not find template %s",
                  task.name,
                  name_or_config
                )
                return
              end
              new_task.cwd = new_task.cwd or task.cwd
              new_task.env = new_task.env or task.env
              if not params.detach then
                self.task_lookup[i] = new_task.id
                table.insert(self.all_tasks, new_task.id)
              end
              -- Don't include after tasks when saving to bundle.
              -- We will re-create them when this task runs again
              new_task:set_include_in_bundle(false)
              new_task:start()
            end)
          end
        end
      end,
      on_reset = function(self, task)
        for _, task_id in pairs(self.task_lookup) do
          local after_task = task_list.get(task_id)
          if after_task then
            after_task:stop()
            after_task:reset()
          end
        end
      end,
      on_dispose = function(self, task)
        for _, task_id in ipairs(self.all_tasks) do
          local after_task = task_list.get(task_id)
          if after_task then
            after_task:stop()
            after_task:dispose()
          end
        end
      end,
    }
  end,
}

return comp
