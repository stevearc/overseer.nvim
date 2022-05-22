local overseer = require("overseer")
local M = {}

M.go_test = {
  name = "go test",
  tags = { overseer.TAG.TEST },
  params = {
    target = { default = "./..." },
  },
  condition = {
    filetype = "go",
  },
  builder = function(params)
    return {
      cmd = { "go", "test", params.target },
    }
  end,
}

return M
