local files = require("overseer.files")
local M = {}

local function get_npm_bin(name)
  local package_bin = files.join("node_modules", ".bin", name)
  if files.exists(package_bin) then
    return package_bin
  end
  return name
end

M.get_cmd = function(defn)
  local cmd = { get_npm_bin("tsc") }
  if defn.tsconfig then
    table.insert(cmd, "-p")
    table.insert(cmd, defn.tsconfig)
  end
  if defn.option then
    table.insert(cmd, string.format("--%s", defn.option))
  end
  return cmd
end

return M
