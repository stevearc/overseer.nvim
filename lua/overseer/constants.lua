local Enum = require("overseer.enum")

local M = {}

M.STATUS = Enum.new({ "PENDING", "RUNNING", "CANCELED", "SUCCESS", "FAILURE" })

M.SLOT = Enum.new({ "RESULT", "NOTIFY", "DISPOSE" })

M.TAG = Enum.new({ "TEST" })

return M
