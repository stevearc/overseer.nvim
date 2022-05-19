local constants = require("overseer.constants")
local SLOT = constants.SLOT
local M = {}

M.register_all = function()
  require("overseer.component").register(M.dispose_delay)
end

M.dispose_delay = {
  name = "dispose_delay",
  description = "Dispose task after a timeout",
  slot = SLOT.DISPOSE,
  params = {
    timeout = {
      description = "Time to wait (in seconds) before disposing",
      optional = true,
    },
  },
  builder = function(opts)
    opts = opts or {}
    vim.validate({
      timeout = { opts.timeout, "n", true },
    })
    -- Default timeout 5 minutes
    opts.timeout = opts.timeout or 300
    return {
      timer = nil,
      on_result = function(self, task)
        self.timer = vim.loop.new_timer()
        self.timer:start(1000 * opts.timeout, 0, vim.schedule_wrap(function()
          task:dispose()
        end))
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
