return {
  desc = "Ability to rerun the task",
  params = {
    delay = {
      desc = "How long to wait (in ms) post-result before triggering rerun",
      default = 500,
      type = "number",
      validate = function(v)
        return v > 0
      end,
    },
    interrupt = {
      desc = "If true, a rerun will cancel a currently running task",
      default = false,
      type = "bool",
    },
  },
  constructor = function(opts)
    vim.validate({
      delay = { opts.delay, "n" },
      interrupt = { opts.interrupt, "b" },
    })
    return {
      rerun_after_result = false,
      _trigger_active = false,
      _trigger_rerun = function(self, task)
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
        self.rerun_after_result = false
      end,
      on_request_rerun = function(self, task)
        if task:is_running() then
          self.rerun_after_result = true
          if opts.interrupt then
            task:stop()
          end
        else
          self:_trigger_rerun(task)
        end
      end,
      on_result = function(self, task)
        if self.rerun_after_result then
          self:_trigger_rerun(task)
        end
      end,
    }
  end,
}
