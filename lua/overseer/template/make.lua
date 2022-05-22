local overseer = require("overseer")
local files = require("overseer.files")
local M = {}

M.make = {
  name = "make",
  tags = { overseer.TAG.BUILD },
  params = {
    args = { optional = true, type = "list" },
  },
  condition = {
    callback = function(self, opts)
      local dir = opts.dir
      return files.exists(files.join(dir, "Makefile"))
    end,
  },
  builder = function(self, params)
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
