local overseer = require("overseer")
local M = {}

M.command = require("overseer.template").new({
  name = "shell command",
  params = {
    command = { type = "list" },
    cwd = { optional = true },
  },
  builder = function(params)
    return {
      cmd = params.command,
      cwd = params.cwd,
    }
  end,
})

M.register_all = function()
  overseer.template.register({ M.command }, {})
end

return M
