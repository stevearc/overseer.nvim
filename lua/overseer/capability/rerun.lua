local constants = require("overseer.constants")

local STATUS = constants.STATUS
local CATEGORY = constants.CATEGORY

local M = {}

M.register_all = function()
  require("overseer.capability").register({
    name = "rerun_trigger",
    description = "Rerun capability",
    category = CATEGORY.RERUN,
    builder = M.rerun_trigger,
  })
  require("overseer.capability").register({
    name = "rerun_on_fail",
    description = "Rerun on failure",
    category = CATEGORY.RERUN,
    builder = M.rerun_on_fail,
  })
  require("overseer.capability").register({
    name = "rerun_on_save",
    description = "Rerun on save",
    category = CATEGORY.RERUN,
    builder = M.rerun_on_save,
  })
end

M.rerun_trigger = function(opts)
  opts = opts or {}
  vim.validate({
    delay = { opts.delay, "n", true },
  })
  opts.delay = opts.delay or 500
  return {
    rerun_after_finalize = false,
    _trigger_active = false,
    _trigger_rerun = function(self, task)
      if self._trigger_active then
        return
      end
      self._trigger_active = true
      vim.defer_fn(function()
        if not task:is_running() and task:is_complete() then
          task:reset()
          task:start()
        end
        self._trigger_active = false
      end, opts.delay)
    end,
    on_reset = function(self, task)
      self.rerun_after_finalize = false
    end,
    on_request_rerun = function(self, task)
      if task:is_running() then
        self.rerun_after_finalize = true
      else
        self:_trigger_rerun(task)
      end
    end,
    on_finalize = function(self, task)
      if self.rerun_after_finalize then
        self:_trigger_rerun(task)
      end
    end,
  }
end

M.rerun_on_save = function(opts)
  opts = opts or {}
  vim.validate({
    delay = { opts.delay, "n", true },
  })
  opts.delay = opts.delay or 500

  return {
    id = nil,
    on_init = function(self, task)
      self.id = vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*",
        desc = string.format("Rerun task %s on save", task.name),
        callback = function()
          task:rerun()
        end,
      })
    end,
    on_dispose = function(self, task)
      vim.api.nvim_del_autocmd(self.id)
      self.id = nil
    end,
  }
end

M.rerun_on_fail = function()
  return {
    on_finalize = function(self, task)
      if task.status == STATUS.FAILURE then
        task:rerun()
      end
    end,
  }
end

return M
