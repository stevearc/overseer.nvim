local constants = require("overseer.constants")
local util = require("overseer.util")
local STATUS = constants.STATUS
local M = {}

M.on_result_notify = {
  name = "on_result_notify",
  description = "vim.notify on result",
  params = {
    statuses = {
      description = "What statuses to notify on",
      type = "list",
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
          local level = M.get_level_from_status(status)
          vim.notify(string.format("%s %s", status, task.name), level)
        end
      end,
    }
  end,
}

M.on_result_notify_red_green = {
  name = "on_result_notify_red_green",
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
          local level = M.get_level_from_status(status)
          vim.notify(string.format("%s %s", status, task.name), level)
          self.last_status = status
        end
      end,
    }
  end,
}

M.get_level_from_status = function(status)
  if status == STATUS.FAILURE then
    return vim.log.levels.ERROR
  elseif status == STATUS.CANCELED then
    return vim.log.levels.WARN
  else
    return vim.log.levels.INFO
  end
end

return M
