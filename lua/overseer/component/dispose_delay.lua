---@type overseer.ComponentDefinition
local comp = {
  desc = "Dispose task after a timeout",
  params = {
    timeout = {
      desc = "Time to wait (in seconds) before disposing",
      default = 300, -- 5 minutes
      type = "number",
      validate = function(v)
        return v > 0
      end,
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

return comp
