local overseer = require("overseer")
local M = {}

M.make = require("overseer.template").new({
  name = "make",
  tags = { overseer.TAG.BUILD },
  params = {
    args = { optional = true, type = "list" },
  },
  builder = function(params)
    local cmd = { "make" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
})

M.register_all = function()
  overseer.template.register({ M.make }, {})
end

return M
