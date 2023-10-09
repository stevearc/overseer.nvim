local Notifier = require("overseer.notifier")
local constants = require("overseer.constants")
local util = require("overseer.util")
local STATUS = constants.STATUS

---@type overseer.ComponentFileDefinition
local comp = {
  desc = "vim.notify when task is completed",
  params = {
    statuses = {
      desc = "List of statuses to notify on",
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
    system = {
      desc = "When to send a system notification",
      type = "enum",
      choices = { "always", "never", "unfocused" },
      default = "never",
    },
    on_change = {
      desc = "Only notify when task status changes from previous value",
      long_desc = "This is mostly used when a task is going to be restarted, and you want notifications only when it goes from SUCCESS to FAILURE, or vice-versa",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    if type(params.statuses) == "string" then
      params.statuses = { params.statuses }
    end
    local lookup = util.list_to_map(params.statuses)

    return {
      last_status = nil,
      notifier = Notifier.new({ system = params.system }),
      on_complete = function(self, task, status)
        if lookup[status] then
          if params.on_change then
            if status == self.last_status then
              return
            end
            self.last_status = status
          end
          local level = util.status_to_log_level(status)
          local message = string.format("%s %s", status, task.name)
          self.notifier:notify(message, level)
        end
      end,
    }
  end,
}
return comp
