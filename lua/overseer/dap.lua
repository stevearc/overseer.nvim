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
      if config.postDebugTask then
        log:trace("Running DAP postDebugTask %s", config.postDebugTask)
        get_task(config.postDebugTask, function(task, err)
          if err then
            log:error("Could not run postDebugTask %s", config.postDebugTask)
          elseif task then
            task:start()
          end
        end)
      end
    end

    if config.preLaunchTask then
      log:trace("Running DAP preLaunchTask %s", config.preLaunchTask)
      get_task(config.preLaunchTask, function(task, err)
        if not task then
          log:error("Could not run preLaunchTask %s: %s", config.preLaunchTask, err)
          return
        end
        local cleanup
        local function on_complete(_, status)
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
          vim.schedule(cleanup)
        end
        local function on_result()
          -- We get the on_result callback from background tasks once they hit their end pattern
          daprun(config, opts)
          vim.schedule(cleanup)
        end
        task:subscribe("on_complete", on_complete)
        task:subscribe("on_result", on_result)
        cleanup = function()
          task:unsubscribe("on_complete", on_complete)
          task:unsubscribe("on_result", on_result)
        end
        task:start()
      end)
    else
      daprun(config, opts)
    end
  end
end

return M
