local constants = require("overseer.constants")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
local M = {}

M.register_all = function()
  require("overseer.component").register({
    name = "notify_result",
    description = "notify on result",
    slot = SLOT.NOTIFY,
    params = {
      statuses = {
        description = "What statuses to notify on",
      },
    },
    builder = M.result_notifier,
  })
end

M.result_notifier = function(opts)
  opts = opts or {}
  if not opts.statuses then
    opts.statuses = {
      STATUS.FAILURE,
      STATUS.SUCCESS,
    }
  elseif type(opts.statuses) == "string" then
    opts.statuses = { opts.statuses }
  end
  local lookup = {}
  for _, v in ipairs(opts.statuses) do
    lookup[v] = true
  end

  return {
    on_result = function(self, task, status)
      if lookup[status] then
        local level = M.get_level_from_status(status)
        vim.notify(string.format("%s %s", status, task.name), level)
      end
    end,
  }
end

M.get_level_from_status = function(status)
  if status == STATUS.FAILURE then
    return vim.log.levels.ERROR
  elseif status == STATUS.STOPPED then
    return vim.log.levels.WARN
  else
    return vim.log.levels.INFO
  end
end

return M
