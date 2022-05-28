local Enum = require("overseer.enum")

local M = {}

M.STATUS = Enum.new({ "PENDING", "RUNNING", "CANCELED", "SUCCESS", "FAILURE" })

M.SLOT = Enum.new({ "RESULT", "DISPOSE" })

M.TAG = Enum.new({ "BUILD", "TEST" })

return M
