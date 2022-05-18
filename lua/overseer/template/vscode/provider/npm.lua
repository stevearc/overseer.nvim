local files = require("overseer.files")
local M = {}

M.get_cmd = function(defn)
  local use_yarn = files.exists("yarn.lock")
  return { use_yarn and "yarn" or "npm", defn.script }
end

return M
