local files = require("overseer.files")
local M = {}

local lockfiles = {
  npm = "package-lock.json",
  pnpm = "pnpm-lock.yaml",
  yarn = "yarn.lock",
  bun = "bun.lockb",
}

local function pick_package_manager()
  for mgr, lockfile in pairs(lockfiles) do
    if files.exists(lockfile) then
      return mgr
    end
  end
  return "npm"
end

M.get_task_opts = function(defn)
  local bin = pick_package_manager()
  return {
    cmd = { bin, defn.script },
  }
end

return M
