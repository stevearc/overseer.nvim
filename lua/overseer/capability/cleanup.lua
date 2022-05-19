local constants = require("overseer.constants")
local CATEGORY = constants.CATEGORY
local M = {}

M.register_all = function()
  require("overseer.capability").register({
    name = "dispose_delay",
    description = "Dispose task after a timeout",
    category = CATEGORY.OTHER,
    builder = M.dispose_delay,
  })
end

M.dispose_delay = function(opts)
  opts = opts or {}
  vim.validate({
    timeout = { opts.timeout, "n", true },
  })
  -- Default timeout 5 minutes
  opts.timeout = opts.timeout or 300000
  return {
    generation = 0,
    on_result = function(self, task)
      local gen = self.generation
      vim.defer_fn(function()
        if self.generation == gen then
          task:dispose()
        end
      end, opts.timeout)
    end,
    on_reset = function(self, task)
      self.generation = self.generation + 1
    end,
  }
end

return M
