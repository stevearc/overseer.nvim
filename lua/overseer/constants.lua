local Enum = require("overseer.enum")

local M = {}

---@alias overseer.Status "PENDING"|"RUNNING"|"CANCELED"|"SUCCESS"|"FAILURE"|"DISPOSED"

M.STATUS = Enum.new({ "PENDING", "RUNNING", "CANCELED", "SUCCESS", "FAILURE", "DISPOSED" })

---@alias overseer.Tag "BUILD"|"RUN"|"TEST"|"CLEAN"

M.TAG = Enum.new({ "BUILD", "RUN", "TEST", "CLEAN" })

return M
