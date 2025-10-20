---@type overseer.ComponentFileDefinition
return {
  desc = "Cancel task if it exceeds a timeout",
  params = {
    timeout = {
      desc = "Time to wait (in seconds) before canceling",
      default = 120,
      type = "integer",
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
      canceled = false,
      on_start = function(self, task)
        self.timer = vim.uv.new_timer()
        self.timer:start(
          1000 * opts.timeout,
          0,
          vim.schedule_wrap(function()
            self.canceled = task:stop()
          end)
        )
      end,
      on_reset = function(self, task)
        self.canceled = false
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
      render = function(self, task, lines, highlights, detail)
        if self.canceled then
          table.insert(lines, "Task timed out")
          table.insert(highlights, { "DiagnosticWarn", #lines, 0, -1 })
        end
      end,
    }
  end,
}
