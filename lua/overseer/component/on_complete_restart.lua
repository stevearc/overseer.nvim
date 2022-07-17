local constants = require("overseer.constants")
local util = require("overseer.util")

local STATUS = constants.STATUS

return {
  desc = "Restart task when it completes",
  params = {
    statuses = {
      desc = "What statuses will trigger a restart",
      type = "list",
      default = { STATUS.FAILURE },
      subtype = {
        type = "enum",
        choices = STATUS.values,
      },
    },
  },
  constructor = function(opts)
    if type(opts.statuses) == "string" then
      opts.statuses = { opts.statuses }
    end
    local lookup = util.list_to_map(opts.statuses)
    return {
      on_complete = function(self, task, status)
        if lookup[status] then
          task:restart()
        end
      end,
    }
  end,
}
