local files = require("overseer.files")
local M = {}

local function pick_package_manager()
  return files.exists(files.join("yarn.lock")) and "yarn"
      or files.exists(files.join("pnpm-lock.yaml")) and "pnpm"
      or "npm"
end

M.get_task_opts = function(defn)
  local bin = pick_package_manager()
  return {
    cmd = { bin, defn.script },
  }
end

return M
