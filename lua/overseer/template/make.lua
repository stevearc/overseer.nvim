local overseer = require("overseer")
local M = {}

M.make = {
  name = "make",
  tags = { overseer.TAG.BUILD },
  params = {
    args = { optional = true, type = "list" },
  },
  condition = {
    callback = function(opts)
      local dir = opts.dir or vim.fn.getcwd(0)
      return overseer.files.path_exists(overseer.files.join(dir, "Makefile"))
    end,
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
}

return M
