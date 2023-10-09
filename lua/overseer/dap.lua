local constants = require("overseer.constants")
local dap = require("dap")
local log = require("overseer.log")
local vscode = require("overseer.template.vscode")
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
  require("overseer").run_template(args, cb)
end

M.wrap_run = function(daprun)
  return function(config, opts)
    dap.listeners.after.event_terminated["overseer"] = function()
      if config.postDebugTask then
        log:trace("Running DAP postDebugTask %s", config.postDebugTask)
        get_task(config.postDebugTask, config, function(task, err)
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
      get_task(config.preLaunchTask, config, function(task, err)
        if not task then
          log:error("Could not run preLaunchTask %s: %s", config.preLaunchTask, err)
          return
        end

        -- Non-background task with problemMatcher will trigger both on_result and on_complete so use the first one
        local done = false
        local cleanup

        local function on_done(ok)
          if done then
            return
          end
          done = true

          if ok then
            daprun(config, opts)
          else
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

        local function on_complete(_, status)
          on_done(status == STATUS.SUCCESS)
        end

        local function on_result()
          -- We get the on_result callback from background tasks once they hit their end pattern
          on_done(task.status ~= STATUS.FAILURE)
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
