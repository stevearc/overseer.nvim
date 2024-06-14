local uv = vim.uv or vim.loop
local constants = require("overseer.constants")
local log = require("overseer.log")
local STATUS = constants.STATUS

---@param bufnr integer
---@return boolean
local function is_buffer_visible(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      return true
    end
  end
  return false
end

---@type overseer.ComponentFileDefinition
local comp = {
  desc = "After task is completed, dispose it after a timeout",
  params = {
    timeout = {
      desc = "Time to wait (in seconds) before disposing",
      default = 300, -- 5 minutes
      type = "number",
      validate = function(v)
        return v > 0
      end,
    },
    statuses = {
      desc = "Tasks with one of these statuses will be disposed",
      type = "list",
      default = { STATUS.SUCCESS, STATUS.FAILURE, STATUS.CANCELED },
      subtype = {
        type = "enum",
        choices = STATUS.values,
      },
    },
    require_view = {
      desc = "Tasks with these statuses must be viewed before they will be disposed",
      type = "list",
      default = {},
      subtype = {
        type = "enum",
        choices = STATUS.values,
      },
    },
  },
  constructor = function(opts)
    opts = opts or {}
    vim.validate({
      timeout = { opts.timeout, "n" },
    })
    return {
      timer = nil,

      _stop_timer = function(self)
        if self.timer then
          self.timer:close()
          self.timer = nil
        end
      end,
      _del_autocmd = function(self)
        if self.autocmd_id then
          vim.api.nvim_del_autocmd(self.autocmd_id)
          self.autocmd_id = nil
        end
      end,
      _start_timer = function(self, task)
        self:_stop_timer()
        log:debug(
          "task(%s)[on_complete_dispose] starting dispose timer for %ds",
          task.id,
          opts.timeout
        )
        self.timer = uv.new_timer()
        -- Start a repeating timer because the dispose could fail with a
        -- temporary reason (e.g. the task buffer is open, or the action menu is
        -- displayed for the task)
        self.timer:start(
          1000 * opts.timeout,
          1000 * opts.timeout,
          vim.schedule_wrap(function()
            log:debug("task(%s)[on_complete_dispose] attempt dispose", task.id)
            task:dispose()
          end)
        )
      end,

      on_complete = function(self, task, status)
        if not vim.tbl_contains(opts.statuses, task.status) then
          log:debug(
            "task(%s)[on_complete_dispose] complete, not auto-disposing task of status %s",
            task.id,
            status
          )
          return
        end
        local bufnr = task:get_bufnr()
        if
          not bufnr
          or is_buffer_visible(bufnr)
          or not vim.tbl_contains(opts.require_view, status)
        then
          self:_start_timer(task)
        else
          log:debug(
            "task(%s)[on_complete_dispose] complete, waiting for output view",
            task.id,
            status
          )
          self.autocmd_id = vim.api.nvim_create_autocmd("BufWinEnter", {
            desc = "Start dispose timer when buffer is visible",
            callback = function(ev)
              if ev.buf ~= bufnr then
                return
              end
              self:_start_timer(task)
              self.autocmd_id = nil
              return true
            end,
          })
        end
      end,
      on_reset = function(self, task)
        self:_del_autocmd()
        self:_stop_timer()
      end,
      on_dispose = function(self, task)
        self:_del_autocmd()
        self:_stop_timer()
      end,
    }
  end,
}

return comp
