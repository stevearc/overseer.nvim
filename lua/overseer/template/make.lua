local M = {}

M.make = require("overseer.template").new({
  name = "make",
  builder = function(params)
    local cmd = { "make" }
    if params.args then
      cmd = vim.list_extend(cmd, vim.split(params.args, "%s"))
    end
    return {
      cmd = cmd,
    }
  end,
  params = {
    args = { optional = true },
  },
})

M.register_all = function()
  require("overseer.template").register({ M.make }, {})
end

return M
