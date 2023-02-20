-- Debug provider for java runtime
local M = {}

local default_debug_port = 5005

M.worker_arg_key = "languageWorkers__java__arguments"

---@param launch_config nil|table
M.get_worker_arg_value = function(launch_config)
  local port = default_debug_port
  if launch_config and launch_config.port then
    port = launch_config.port
  end
  return string.format("-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=%s", port)
end

return M
