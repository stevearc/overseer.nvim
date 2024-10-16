local util = require("overseer.util")
local uv = vim.uv or vim.loop

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
  desc = "Use nvim-notify to show notification with task output summary for long-running tasks",

  long_desc = vim.trim([[
Works like on_complete_notify but, for long-running commands, also shows real-time output summary (like on_output_summarize).
Requires nvim-notify to modify the last notification window when new output arrives instead of creating new notification.
  ]]),

  params = {
    max_lines = {
      desc = "Number of lines of output to show",
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
    delay_ms = {
      desc = "Time in milliseconds to wait before displaying the notification during task runtime",
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
      desc = "Show the last lines of task output and status on completion (instead of only the status)",
      long_desc = vim.trim([[
When output_on_complete==true: shows status + last output lines during task runtime and after completion.
When output_on_complete==false: shows status + last output lines during task runtime and only status after completion.
      ]]),
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
          self.lines = util.get_last_output_lines(bufnr, num_lines)
          self:update_notification(task)
        end
      end, { delay = 10, reset_timer_on_call = true }),

      update_notification = function(self, task)
        -- Don't notify on output without nvim-notify installed, as this would create
        -- a lot of separate notifications instead of replacing the same one.
        if task:is_running() and not has_nvim_notify() then
          vim.notify_once(
            "overseer.component.on_output_notify requires nvim-notify",
            vim.log.levels.WARN
          )
          return
        end

        local header = string.format("%s %s", task.status, task.name)
        local max_width = math.max(params.max_width or 0, #header)
        local lines = { header }
        if task:is_running() or params.output_on_complete then
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
          timeout = not task:is_running() and get_notify_config("default_timeout", 5000) or false,
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
        self.start_time = uv.now()
      end,

      on_output = function(self, task, _data)
        local elapsed = uv.now() - self.start_time
        if elapsed < params.delay_ms then
          return
        end

        local bufnr = task:get_bufnr()
        self.lines = util.get_last_output_lines(bufnr, params.max_lines)
        self:update_notification(task)

        -- Update again after delay because the terminal buffer takes a few millis to be updated
        -- after output is received
        self.defer_update_lines(self, task, bufnr, params.max_lines)
      end,

      on_complete = function(self, task, _status)
        self:update_notification(task)
      end,
    }
  end,
}

return comp
