local constants = require("overseer.constants")
local util = require("overseer.util")
local STATUS = constants.STATUS

local M = {}

M.on_status_run_task = {
  name = "on_status_run_task",
  description = "run another task on status change",
  params = {
    status = {
      description = "What status to trigger on",
      default = STATUS.SUCCESS,
    },
    task_names = {
      description = "Names of the task template to trigger",
      type = "list",
    },
    sequence = {
      description = "When true, tasks run one after another",
      type = "bool",
      optional = true,
    },
    once = {
      type = "bool",
      description = "When true, only trigger task once then remove self",
      default = true,
    },
  },
  constructor = function(params)
    local ret = {}
    local function trigger(self, task)
      if task.status ~= params.status then
        return
      end
      local commands = require("overseer.commands")
      local i = 1
      local function run_next()
        if i > #params.task_names then
          return
        end
        local name = params.task_names[i]
        i = i + 1
        commands.run_template({ name = name, prompt = "allow" }, {}, function(new_task)
          if params.sequence then
            new_task:add_component({
              "on_status_run_task",
              status = params.status,
              sequence = params.sequence,
              once = params.once,
              task_names = util.tbl_slice(params.task_names, 2),
            })
          else
            run_next()
          end
        end)
      end
      run_next()
      if params.once then
        vim.defer_fn(function()
          task:remove_component("on_status_run_task")
        end, 1)
      end
    end
    if params.status == STATUS.PENDING then
      ret.on_init = trigger
    elseif params.status == STATUS.RUNNING then
      ret.on_start = trigger
    elseif params.status == STATUS.DISPOSED then
      ret.on_dispose = trigger
    else
      ret.on_result = trigger
    end
    return ret
  end,
}

return M
