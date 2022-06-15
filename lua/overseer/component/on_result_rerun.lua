local constants = require("overseer.constants")
local util = require("overseer.util")

local STATUS = constants.STATUS

return {
  description = "Rerun when task ends",
  params = {
    statuses = {
      description = "What statuses will trigger a rerun",
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
      on_result = function(self, task, status)
        if lookup[status] then
          task:rerun()
        end
      end,
    }
  end,
}
