local M = {}

M.go_test = require("overseer.template").new({
  name = "run test",
  description = "go test <directory>",
  builder = function(params)
    return {
      cmd = { "go", "test", params.dirname },
    }
  end,
  params = {
    dirname = {},
  },
})

M.register_all = function()
  require("overseer.template").register({ M.go_test }, { filetype = "go" })
end

return M
