local constants = require("overseer.constants")
local util = require("overseer.util")
local STATUS = constants.STATUS

local function get_level_from_status(status)
  if status == STATUS.FAILURE then
    return vim.log.levels.ERROR
  elseif status == STATUS.CANCELED then
    return vim.log.levels.WARN
  else
    return vim.log.levels.INFO
  end
end

return {
  desc = "vim.notify on task result",
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
          local level = get_level_from_status(status)
          vim.notify(string.format("%s %s", status, task.name), level)
        end
      end,
    }
  end,
}
