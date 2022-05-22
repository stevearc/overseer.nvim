local constants = require("overseer.constants")
local SLOT = constants.SLOT
local M = {}

M.dispose_delay = {
  name = "dispose_delay",
  description = "Dispose task after a timeout",
  slot = SLOT.DISPOSE,
  params = {
    timeout = {
      description = "Time to wait (in seconds) before disposing",
      default = 300, -- 5 minutes
      type = "number",
    },
  },
  constructor = function(opts)
    opts = opts or {}
    vim.validate({
      timeout = { opts.timeout, "n" },
    })
    return {
      timer = nil,
      on_result = function(self, task)
        self.timer = vim.loop.new_timer()
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

return M
