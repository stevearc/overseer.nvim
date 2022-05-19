local M = {}

M.setup = function(opts)
  local cap = require("overseer.capability")
  cap.alias("default", {
    "output_summary",
    "exit_code",
    "notify_success_failure",
    "rerun_trigger",
  })
  cap.alias("default_once", {
    "output_summary",
    "exit_code",
    "notify_success_failure",
    "dispose_delay",
  })
  cap.alias("default_up", {
    "output_summary",
    "exit_code",
    "notify_failure",
    "rerun_trigger",
    "rerun_on_fail",
  })
  cap.alias("default_watch", {
    "output_summary",
    "exit_code",
    "notify_failure",
    "rerun_trigger",
    "rerun_on_save",
  })
end

M.get_default_notifier = function()
  local notify = require("overseer.notify")
  return notify.new_on_result_notifier()
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
