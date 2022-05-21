local overseer = require("overseer")
local M = {}

M.go_test = require("overseer.template").new({
  name = "go test",
  tags = { overseer.TAG.TEST },
  params = {
    target = { default = "./..." },
  },
  builder = function(params)
    return {
      cmd = { "go", "test", params.target },
    }
  end,
})

M.register_all = function()
  overseer.template.register({ M.go_test }, { filetype = "go" })
end

return M
