local constants = require("overseer.constants")
local Notifier = require("overseer.notifier")
local util = require("overseer.util")
local STATUS = constants.STATUS

return {
  desc = "vim.notify when task receives results",
  long_desc = "Normally you will want to use on_complete_notify. If you have a long-running watch task (e.g. `tsc --watch`) that produces new results periodically, then this is the component you want.",
  params = {
    system = {
      desc = "When to send a system notification",
      type = "enum",
      choices = { "always", "never", "unfocused" },
      default = "never",
    },
    on_change = {
      desc = "Only notify when status changes from previous value",
      long_desc = "This only works when infer_status_from_diagnostics = true",
      type = "boolean",
      default = true,
    },
    infer_status_from_diagnostics = {
      desc = "Notification level will be error/info depending on if diagnostics are present",
      type = "boolean",
      default = true,
    },
  },
  constructor = function(params)
    return {
      last_status = nil,
      notifier = Notifier.new({ system = params.system }),
      on_result = function(self, task, result)
        local status = STATUS.SUCCESS
        if params.infer_status_from_diagnostics then
          if result.diagnostics and not vim.tbl_isempty(result.diagnostics) then
            status = STATUS.FAILURE
          end
        end
        if params.on_change then
          if status == self.last_status then
            return
          end
          self.last_status = status
        end
        local level = util.status_to_log_level(status)
        local message = string.format("%s %s", status, task.name)
        self.notifier:notify(message, level)
      end,
    }
  end,
}
