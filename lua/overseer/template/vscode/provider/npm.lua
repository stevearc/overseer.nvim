local files = require("overseer.files")
local M = {}

M.get_task_opts = function(defn)
  local use_yarn = files.exists("yarn.lock")
  return {
    cmd = { use_yarn and "yarn" or "npm", defn.script },
  }
end

return M
