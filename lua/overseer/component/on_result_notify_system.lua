local constants = require("overseer.constants")
local on_result_notify = require("overseer.component.on_result_notify")
local files = require("overseer.files")
local util = require("overseer.util")
local STATUS = constants.STATUS

return {
  description = "send a system notification when task completes",
  system_notify = function(message, level)
    if files.is_windows then
      -- TODO
    elseif files.is_mac then
      vim.fn.jobstart({
        "reattach-to-user-namespace",
        "osascript",
        "-e",
        string.format(
          'display notification "%s" with title "%s"',
          "Overseer task complete",
          message
        ),
      }, {
        stdin = "null",
      })
    else
      local urgency = level == vim.log.levels.INFO and "normal" or "critical"
      vim.fn.jobstart({
        "notify-send",
        "-u",
        urgency,
        "Overseer task complete",
        message,
      }, {
        stdin = "null",
      })
    end
  end,
  params = {
    statuses = {
      description = "What statuses to notify on",
      type = "list",
      subtype = {
        type = "enum",
        choices = STATUS.values,
      },
      default = {
        STATUS.FAILURE,
        STATUS.SUCCESS,
      },
    },
  },
  constructor = function(opts)
    opts = opts or {}
    if type(opts.statuses) == "string" then
      opts.statuses = { opts.statuses }
    end
    local lookup = util.list_to_map(opts.statuses)

    return {
      on_result = function(self, task, status)
        if lookup[status] then
          local level = on_result_notify.get_level_from_status(status)
          self.system_notify(string.format("%s %s", status, task.name), level)
        end
      end,
    }
  end,
}
