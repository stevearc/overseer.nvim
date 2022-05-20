local constants = require("overseer.constants")
local util = require("overseer.util")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
local M = {}

M.register_all = function()
  require("overseer.component").register(M.notify_result)
  require("overseer.component").register(M.notify_red_green)
end

M.notify_result = {
  name = "notify_result",
  description = "notify on result",
  slot = SLOT.NOTIFY,
  params = {
    statuses = {
      description = "What statuses to notify on",
      optional = true,
    },
  },
  builder = function(opts)
    opts = opts or {}
    if not opts.statuses then
      opts.statuses = {
        STATUS.FAILURE,
        STATUS.SUCCESS,
      }
    elseif type(opts.statuses) == "string" then
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

M.notify_red_green = {
  name = "notify_red_green",
  description = "notify when task fails, or when it goes from failing to success",
  slot = SLOT.NOTIFY,
  params = {},
  builder = function()
    return {
      last_status = nil,
      on_result = function(self, task, status)
        if
          status == STATUS.FAILURE
          or (status == STATUS.SUCCESS and self.last_status == STATUS.FAILURE)
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
