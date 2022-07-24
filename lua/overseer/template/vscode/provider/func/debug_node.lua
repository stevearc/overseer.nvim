-- Debug provider for node runtime
local M = {}

local default_debug_port = 9229

M.worker_arg_key = "languageWorkers__node__arguments"

M.get_worker_arg_value = function()
  -- TODO we don't yet support fetching the debug port from the launch.json configuration
  return string.format("--inspect=%s", default_debug_port)
end

return M
