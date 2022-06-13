local on_result_notify = require("overseer.component.on_result_notify")
local constants = require("overseer.constants")
local STATUS = constants.STATUS

return {
  description = "notify when task fails, or when it goes from failing to success",
  params = {},
  constructor = function()
    return {
      last_status = nil,
      on_result = function(self, task, status)
        if
          status == STATUS.FAILURE
          or (status == STATUS.SUCCESS and self.last_status ~= STATUS.SUCCESS)
        then
          local level = on_result_notify.get_level_from_status(status)
          vim.notify(string.format("%s %s", status, task.name), level)
          self.last_status = status
        end
      end,
    }
  end,
}
