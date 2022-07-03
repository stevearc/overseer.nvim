local log = require("overseer.log")
local M = {}

M.validate = function(defn)
  if not defn.dependsOn then
    log:warn("VS Code task '%s' has no command and no dependsOn tasks", defn.label)
    return false
  end
  return true
end

M.get_cmd = function(defn)
  -- FIXME this is a hack. Once we get a "function" run strategy, we can
  -- refactor this into something better
  return { "sleep", "1" }
end

return M
