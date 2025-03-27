-- Debug provider for node runtime
local M = {}

local default_debug_port = 9229

M.worker_arg_key = "languageWorkers__node__arguments"

---@param launch_config nil|table
M.get_worker_arg_value = function(launch_config)
  local port = default_debug_port
  if launch_config and launch_config.port then
    port = launch_config.port
  end
  return string.format("--inspect=%s", port)
end

return M
