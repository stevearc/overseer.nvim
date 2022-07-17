local constants = require("overseer.constants")
local Notifier = require("overseer.notifier")
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
    desktop = {
      desc = "When to use a desktop notification",
      type = "enum",
      choices = { "always", "never", "unfocused" },
      default = "never",
    },
  },
  constructor = function(opts)
    opts = opts or {}
    if type(opts.statuses) == "string" then
      opts.statuses = { opts.statuses }
    end
    local lookup = util.list_to_map(opts.statuses)

    return {
      notifier = Notifier.new({ desktop = opts.desktop }),
      on_complete = function(self, task, status)
        if lookup[status] then
          local level = get_level_from_status(status)
          local message = string.format("%s %s", status, task.name)
          self.notifier:notify(message, level)
        end
      end,
    }
  end,
}
