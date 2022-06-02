local parser = require("overseer.parser")
local M = {}

M.run_parser = function(integration, output)
  local defn = integration.parser()
  local p = parser.new(defn)
  p:ingest(vim.split(output, "\n"))
  return p:get_result()
end

return M
