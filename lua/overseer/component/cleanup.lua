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
      generation = 0,
      on_result = function(self, task)
        local gen = self.generation
        vim.defer_fn(function()
          if self.generation == gen then
            task:dispose()
          end
        end, opts.timeout * 1000)
      end,
      on_reset = function(self, task)
        self.generation = self.generation + 1
      end,
    }
  end,
}

return M
