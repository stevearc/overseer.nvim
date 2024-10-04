-- Like on_complete_notify but, for long-running commands, also show real-time output summary (based on on_output_summarize).
-- Requires nvim-notify to modify the last notification window when new output arrives instead of creating new notification.

local util = require("overseer.util")

---@param bufnr integer
---@param num_lines integer
---@return string[]
local function get_last_lines(bufnr, num_lines)
  local end_line = vim.api.nvim_buf_line_count(bufnr)
  num_lines = math.min(num_lines, end_line)
  local lines = {}
  while end_line > 0 and #lines < num_lines do
    local need_lines = num_lines - #lines
    lines = vim.list_extend(
      vim.api.nvim_buf_get_lines(bufnr, math.max(0, end_line - need_lines), end_line, false),
      lines
    )
    while
      not vim.tbl_isempty(lines)
      and (lines[#lines]:match("^%s*$") or lines[#lines]:match("^%[Process exited"))
    do
      table.remove(lines)
    end
    end_line = end_line - need_lines
  end
  return lines
end

local function has_nvim_notify()
  return not not pcall(require, "notify")
end

local function get_notify_config(setting, default)
  local notify_setting = vim.F.npcall(function()
    return require("notify")._config()[setting]()
  end)
  return vim.F.if_nil(notify_setting, default)
end

---@type overseer.ComponentFileDefinition
local comp = {
  desc = "Notify with task output summary for long-running tasks or when completed",

  params = {
    max_lines = {
      desc = "Number of lines of output to show when detail > 1",
      type = "integer",
      default = 1,
      validate = function(v)
        return v > 0
      end,
    },
    max_width = {
      desc = "Maximum output width",
      type = "integer",
      optional = true,
      default = get_notify_config("max_width", 49),
      validate = function(v)
        return v > 0
      end,
    },
    min_duration = {
      desc = "Minimum duration in milliseconds after which to display the notification",
      type = "number",
      default = 2000,
      validate = function(v)
        return v >= 0
      end,
    },
    trim = {
      desc = "Remove whitespace from both sides of each line",
      type = "boolean",
      default = true,
    },
    output_on_complete = {
      desc = "Show output summary even when the task completed",
      type = "boolean",
      default = false,
    },
  },

  constructor = function(params)
    return {
      lines = {},
      notification_id = nil,
      last_status = nil,
      start_time = nil,

      defer_update_lines = util.debounce(function(self, task, bufnr, num_lines)
        if vim.api.nvim_buf_is_valid(bufnr) then
          self.lines = get_last_lines(bufnr, num_lines)
          self:update_notification(task)
        end
      end, { delay = 10, reset_timer_on_call = true }),

      update_notification = function(self, task, complete)
        -- Don't notify on output without nvim-notify installed, as this would create
        -- a lot of separate notifications instead of replacing the same one.
        if not complete and not has_nvim_notify() then
          vim.notify_once(
            "overseer.component.on_output_notify requires nvim-notify",
            vim.log.levels.WARN
          )
          return
        end

        local header = string.format("%s %s", task.status, task.name)
        local max_width = math.max(params.max_width or 0, #header)
        local lines = { header }
        if not complete or params.output_on_complete then
          for _, line in ipairs(self.lines) do
            if params.trim then
              line = vim.trim(line)
            end
            if #line > max_width then
              line = line:sub(1, max_width - 1) .. "…"
            end
            table.insert(lines, line)
          end
        end
        local msg = table.concat(lines, "\n")

        local level = util.status_to_log_level(task.status)
        local ret = vim.notify(msg, level, {
          replace = self.notification_id,
          hide_from_history = self.notification_id and self.last_status == task.status,
          timeout = complete and get_notify_config("default_timeout", 5000) or false,
        })
        self.notification_id = ret and ret.id
        self.last_status = task.status
      end,

      on_reset = function(self)
        self.lines = {}
        self.notification_id = nil
        self.last_status = nil
        self.start_time = nil
      end,

      on_start = function(self)
        self.start_time = vim.uv.now()
      end,

      on_output = function(self, task, _data)
        local elapsed = vim.uv.now() - self.start_time
        if elapsed < params.min_duration then
          return
        end

        local bufnr = task:get_bufnr()
        self.lines = get_last_lines(bufnr, params.max_lines)
        self:update_notification(task)

        -- Update again after delay because the terminal buffer takes a few millis to be updated
        -- after output is received
        self.defer_update_lines(self, task, bufnr, params.max_lines)
      end,

      on_complete = function(self, task, _status)
        self:update_notification(task, true)
      end,
    }
  end,
}

return comp
