-- Debug provider for java runtime
local M = {}

local default_debug_port = 5005

M.worker_arg_key = "languageWorkers__java__arguments"

M.get_worker_arg_value = function()
  -- TODO we don't yet support fetching the debug port from the launch.json configuration
  return string.format(
    "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=%s",
    default_debug_port
  )
end

return M
