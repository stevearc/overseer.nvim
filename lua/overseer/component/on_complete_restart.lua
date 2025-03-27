local constants = require("overseer.constants")
local util = require("overseer.util")

local STATUS = constants.STATUS

---@type overseer.ComponentFileDefinition
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
    delay = {
      desc = "How long to wait (in ms) post-result before triggering restart",
      default = 500,
      type = "number",
      validate = function(v)
        return v > 0
      end,
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
          vim.defer_fn(function()
            -- Only continue with the restart if the status hasn't changed
            if task.status == status then
              task:restart()
            end
          end, opts.delay)
        end
      end,
    }
  end,
}
