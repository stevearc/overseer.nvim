local constants = require("overseer.constants")
local dap = require("dap")
local log = require("overseer.log")
local vscode = require("overseer.vscode")
local STATUS = constants.STATUS
local TAG = constants.TAG
local M = {}

---@param name string
---@param config table
---@param cb fun(task: overseer.Task|nil, err: string|nil)
local function get_task(name, config, cb)
  -- Pass the launch.json config data into the params for the task as a special key
  local args = { autostart = false, params = { [vscode.LAUNCH_CONFIG_KEY] = config } }
  if name == "${defaultBuildTask}" then
    args.tags = { TAG.BUILD }
  else
    args.name = name
  end
  require("overseer").run_task(args, cb)
end

M.listener = function(config)
  dap.listeners.after.event_terminated.overseer = nil
  if not config.preLaunchTask and not config.postDebugTask then
    return config
  end

  if config.postDebugTask then
    dap.listeners.after.event_terminated.overseer = function()
      log.debug("Running DAP postDebugTask %s", config.postDebugTask)
      get_task(config.postDebugTask, config, function(task, err)
        if err then
          log.error("Could not run postDebugTask %s", config.postDebugTask)
        elseif task then
          task:start()
        end
      end)
    end
  end

  if config.preLaunchTask then
    log.debug("Running DAP preLaunchTask %s", config.preLaunchTask)
    local co = coroutine.running()
    get_task(config.preLaunchTask, config, function(task, err)
      if not task then
        log.error("Could not run preLaunchTask %s: %s", config.preLaunchTask, err)
        return
      end

      -- Non-background task with problemMatcher will trigger both on_result and on_complete so use the first one
      local on_done
      on_done = function(ok)
        on_done = function() end

        if not ok then
          vim.notify(
            string.format("DAP preLaunchTask '%s' failed", config.preLaunchTask),
            vim.log.levels.ERROR
          )
        else
          coroutine.resume(co)
        end
      end

      local function on_complete(_, status)
        on_done(status == STATUS.SUCCESS)
        return false
      end

      local function on_result()
        -- We get the on_result callback from background tasks once they hit their end pattern
        on_done(task.status ~= STATUS.FAILURE)
        return false
      end

      task:subscribe("on_complete", on_complete)
      task:subscribe("on_result", on_result)
      task:start()
    end)

    coroutine.yield()
  end

  return config
end

return M
