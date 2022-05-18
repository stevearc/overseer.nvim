local M = {}

M.setup = function(opts) end

M.get_default_notifier = function()
  local notify = require("overseer.notify")
  return notify.new_on_exit_notifier()
end

M.get_default_summarizer = function()
  local result = require("overseer.result")
  return result.new_output_summarizer()
end

M.get_default_finalizer = function()
  local result = require("overseer.result")
  return result.new_exit_code_finalizer()
end

M.get_default_rerunner = function()
  local rerun = require("overseer.rerun")
  return rerun.new_rerun_on_trigger()
end

return M
