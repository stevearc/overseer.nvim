local constants = require("overseer.constants")
local STATUS = constants.STATUS
local M = {}

M.wrap_run = function(daprun)
  return function(config, opts)
    if config.preLaunchTask then
      require("overseer").run_template(
        { name = config.preLaunchTask, nostart = true },
        function(task, err)
          if err then
            require("overseer.log"):error("Could not run preLaunchTask %s", config.preLaunchTask)
            return
          end
          task:add_component({
            "on_complete_callback",
            callback = function(_, status)
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
            end,
          })
          task:start()
        end
      )
    else
      daprun(config, opts)
    end
  end
end

return M
