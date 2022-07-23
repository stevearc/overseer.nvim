local constants = require("overseer.constants")
local dap = require("dap")
local log = require("overseer.log")
local STATUS = constants.STATUS
local TAG = constants.TAG
local M = {}

---@param name string
---@param cb fun(task: overseer.Task|nil, err: string|nil)
local function get_task(name, cb)
  local args = { autostart = false }
  if name == "${defaultBuildTask}" then
    args.tags = { TAG.BUILD }
  else
    args.name = name
  end
  require("overseer").run_template(args, cb)
end

M.wrap_run = function(daprun)
  return function(config, opts)
    dap.listeners.after.event_terminated["overseer"] = function()
      get_task(config.postDebugTask, function(task, err)
        if err then
          log:error("Could not run postDebugTask %s", config.postDebugTask)
        elseif task then
          task:start()
        end
      end)
    end

    if config.preLaunchTask then
      get_task(config.preLaunchTask, function(task, err)
        if not task then
          log:error("Could not run preLaunchTask %s: %s", config.preLaunchTask, err)
          return
        end
        task:add_component({
          "on_complete_callback",
          on_complete = function(_, status)
            if status == STATUS.SUCCESS then
              daprun(config, opts)
            elseif status == STATUS.FAILURE then
              vim.notify(
                string.format(
                  "Failed to launch debugger; preLaunchTask '%s' failed",
                  config.preLaunchTask
                ),
                vim.log.levels.ERROR
              )
            end
            vim.schedule(function()
              task:remove_component("on_complete_callback")
            end)
          end,
          on_result = function(_, status)
            -- We get the on_result callback from background tasks once they hit their end pattern
            daprun(config, opts)
            vim.schedule(function()
              task:remove_component("on_complete_callback")
            end)
          end,
        })
        task:start()
      end)
    else
      daprun(config, opts)
    end
  end
end

return M
