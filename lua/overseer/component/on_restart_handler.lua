return {
  desc = "Allows task to be restarted",
  params = {
    delay = {
      desc = "How long to wait (in ms) post-result before triggering restart",
      default = 500,
      type = "number",
      validate = function(v)
        return v > 0
      end,
    },
    interrupt = {
      desc = "If true, a restart will cancel a currently running task",
      default = false,
      type = "boolean",
    },
  },
  constructor = function(opts)
    vim.validate({
      delay = { opts.delay, "n" },
      interrupt = { opts.interrupt, "b" },
    })
    return {
      restart_after_result = false,
      _trigger_active = false,
      _trigger_restart = function(self, task)
        if self._trigger_active then
          return
        end
        self._trigger_active = true
        vim.defer_fn(function()
          if not task:is_running() and task:is_complete() and not task:is_disposed() then
            task:reset()
            task:start()
          end
          self._trigger_active = false
        end, opts.delay)
      end,
      on_reset = function(self, task)
        self.restart_after_result = false
      end,
      on_request_restart = function(self, task)
        if task:is_running() then
          self.restart_after_result = true
          if opts.interrupt then
            task:stop()
          end
        else
          self:_trigger_restart(task)
        end
      end,
      on_result = function(self, task)
        if self.restart_after_result then
          self:_trigger_restart(task)
        end
      end,
    }
  end,
}
