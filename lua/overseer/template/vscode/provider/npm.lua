local files = require("overseer.files")
local util = require("overseer.util")
local M = {}

---@type table<string, string[]>
local mgr_lockfiles = {
  npm = { "package-lock.json" },
  pnpm = { "pnpm-lock.yaml" },
  yarn = { "yarn.lock" },
  bun = { "bun.lockb", "bun.lock" },
}

local function pick_package_manager()
  for mgr, lockfiles in pairs(mgr_lockfiles) do
    if util.list_any(lockfiles, function(lockfile)
      return files.exists(lockfile)
    end) then
      return mgr
    end
  end
  return "npm"
end

M.get_task_opts = function(defn)
  local bin = pick_package_manager()
  local cmd = { bin, defn.script }
  if bin == "npm" then
    -- npm runs scripts with `npm run`
    table.insert(cmd, 2, "run")
  end
  return {
    cmd = cmd,
  }
end

return M
