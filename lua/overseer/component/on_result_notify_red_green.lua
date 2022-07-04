local on_result_notify = require("overseer.component.on_result_notify")
local constants = require("overseer.constants")
local Notifier = require("overseer.notifier")
local STATUS = constants.STATUS

return {
  desc = "vim.notify when task fails, or when it goes from failing to success",
  params = {
    desktop = {
      desc = "When to use a desktop notification",
      type = "enum",
      choices = { "always", "never", "unfocused" },
      default = "never",
    },
  },
  constructor = function(opts)
    return {
      last_status = nil,
      notifier = Notifier.new({ desktop = opts.desktop }),
      on_result = function(self, task, status)
        if
          status == STATUS.FAILURE
          or (status == STATUS.SUCCESS and self.last_status ~= STATUS.SUCCESS)
        then
          local level = on_result_notify.get_level_from_status(status)
          local message = string.format("%s %s", status, task.name)
          self.notifier:notify(message, level)
          self.last_status = status
        end
      end,
    }
  end,
}
