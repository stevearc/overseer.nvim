local constants = require("overseer.constants")
local util = require("overseer.util")

local STATUS = constants.STATUS

local M = {}

M.register_all = function()
  require("overseer.component").register(M.rerun_trigger)
  require("overseer.component").register(M.rerun_on_result)
  require("overseer.component").register(M.rerun_on_save)
end

M.rerun_trigger = {
  name = "rerun_trigger",
  description = "Ability to rerun the task",
  params = {
    delay = {
      description = "How long to wait (in ms) post-result before triggering rerun",
      optional = true,
    },
  },
  builder = function(opts)
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
  end,
}

M.rerun_on_save = {
  name = "rerun_on_result",
  description = "Rerun on result",
  params = {
    delay = {
      description = "How long to wait (in ms) post-result before triggering rerun",
      optional = true,
    },
  },
  builder = function(opts)
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
  end,
}

M.rerun_on_result = {
  name = "rerun_on_save",
  description = "Rerun on save",
  params = {
    statuses = {
      description = "What statuses to notify on",
      optional = true,
    },
  },
  builder = function(opts)
    opts = opts or {}
    if not opts.statuses then
      opts.statuses = { STATUS.FAILURE }
    elseif type(opts.statuses) == "string" then
      opts.statuses = { opts.statuses }
    end
    local lookup = util.list_to_map(opts.statuses)
    return {
      on_finalize = function(self, task)
        if lookup[task.status] then
          task:rerun()
        end
      end,
    }
  end,
}

return M
