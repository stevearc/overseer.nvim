local Enum = require("overseer.enum")

local M = {}

M.STATUS = Enum.new({ "PENDING", "RUNNING", "CANCELED", "SUCCESS", "FAILURE", "DISPOSED" })

M.TAG = Enum.new({ "BUILD", "TEST" })

return M
