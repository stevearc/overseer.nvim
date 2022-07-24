-- Debug provider for powershell runtime
local M = {}

M.worker_arg_key = "PSWorkerCustomPipeName"

M.get_worker_arg_value = function()
  return "AzureFunctionsPSWorker"
end

return M
