local constants = require("overseer.constants")
local files = require("overseer.files")
local util = require("overseer.util")

local STATUS = constants.STATUS

local M = {}

M.on_rerun_handler = {
  name = "on_rerun_handler",
  description = "Ability to rerun the task",
  params = {
    delay = {
      description = "How long to wait (in ms) post-result before triggering rerun",
      default = 500,
      type = "number",
    },
    interrupt = {
      description = "If true, a rerun will cancel a currently running task",
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
          if opts.interrupt then
            task:stop()
          end
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
  name = "rerun_on_save",
  description = "Rerun on any buffer :write",
  params = {
    dir = {
      name = "directory",
      description = "Only rerun when writing files in this directory",
      optional = true,
    },
    delay = {
      description = "How long to wait (in ms) post-result before triggering rerun",
      type = "number",
      default = 500,
    },
  },
  constructor = function(opts)
    vim.validate({
      delay = { opts.delay, "n" },
      dir = { opts.dir, "s", true },
    })

    return {
      id = nil,
      on_init = function(self, task)
        task:inc_reference()
        self.id = vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "*",
          desc = string.format("Rerun task %s on save", task.name),
          callback = function(params)
            -- Only care about normal files
            if vim.api.nvim_buf_get_option(params.buf, "buftype") == "" then
              local bufname = vim.api.nvim_buf_get_name(params.buf)
              if not opts.dir or files.is_subpath(opts.dir, bufname) then
                task:rerun()
              end
            end
          end,
        })
      end,
      on_dispose = function(self, task)
        task:dec_reference()
        vim.api.nvim_del_autocmd(self.id)
        self.id = nil
      end,
    }
  end,
}

M.rerun_on_result = {
  name = "rerun_on_result",
  description = "Rerun when task ends",
  params = {
    statuses = {
      description = "What statuses will trigger a rerun",
      type = "list",
      default = { STATUS.FAILURE },
    },
  },
  constructor = function(opts)
    if type(opts.statuses) == "string" then
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
