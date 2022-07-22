local constants = require("overseer.constants")
local STATUS = constants.STATUS

---@type overseer.ComponentDefinition
local comp = {
  desc = "After task is completed, dispose it after a timeout",
  params = {
    timeout = {
      desc = "Time to wait (in seconds) before disposing",
      default = 300, -- 5 minutes
      type = "number",
      validate = function(v)
        return v > 0
      end,
    },
    statuses = {
      desc = "Tasks with one of these statuses will be disposed",
      type = "list",
      default = { STATUS.SUCCESS, STATUS.FAILURE, STATUS.CANCELED },
      subtype = {
        type = "enum",
        choices = STATUS.values,
      },
    },
  },
  constructor = function(opts)
    opts = opts or {}
    vim.validate({
      timeout = { opts.timeout, "n" },
    })
    return {
      timer = nil,
      on_complete = function(self, task)
        if not vim.tbl_contains(opts.statuses, task.status) then
          return
        end
        self.timer = vim.loop.new_timer()
        -- Start a repeating timer because the dispose could fail with a
        -- temporary reason (e.g. the task buffer is open, or the action menu is
        -- displayed for the task)
        self.timer:start(
          1000 * opts.timeout,
          1000 * opts.timeout,
          vim.schedule_wrap(function()
            task:dispose()
          end)
        )
      end,
      on_reset = function(self, task)
        if self.timer then
          self.timer:close()
          self.timer = nil
        end
      end,
      on_dispose = function(self, task)
        if self.timer then
          self.timer:close()
          self.timer = nil
        end
      end,
    }
  end,
}

return comp
