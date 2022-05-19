local constants = require("overseer.constants")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
local M = {}

M.register_all = function()
  require("overseer.capability").register({
    name = "notify_success_failure",
    description = "notify on success/failure",
    slot = SLOT.NOTIFY,
    builder = function()
      return M.result_notifier({ when = M.NOTIFY.SUCCESS_FAILURE })
    end,
  })
  require("overseer.capability").register({
    name = "notify_failure",
    description = "notify on failure",
    slot = SLOT.NOTIFY,
    builder = function()
      return M.result_notifier({ when = M.NOTIFY.FAILURE })
    end,
  })
end

M.NOTIFY = {
  NEVER = "never",
  SUCCESS_FAILURE = "success_failure",
  ALWAYS = "always",
  SUCCESS = "success",
  FAILURE = "failure",
}

M.result_notifier = function(opts)
  opts = opts or {}
  vim.validate({
    when = { opts.when, "s", true },
    format = { opts.format, "f", true },
  })
  return {
    when = opts.when or M.NOTIFY.SUCCESS_FAILURE,
    format = opts.format,
    on_result = function(self, task, status)
      M.vim_notify_from_status(task, status, self.when, self.format)
    end,
  }
end

M.get_level_from_status = function(status)
  if status == STATUS.FAILURE then
    return vim.log.levels.ERROR
  elseif status == STATUS.STOPPED then
    return vim.log.levels.WARN
  else
    return vim.log.levels.INFO
  end
end

M.vim_notify_from_status = function(task, status, enum, format)
  enum = enum or M.NOTIFY.ALWAYS
  if
    enum == M.NOTIFY.ALWAYS
    or ((enum == M.NOTIFY.SUCCESS or enum == M.NOTIFY.SUCCESS_FAILURE) and status == STATUS.SUCCESS)
    or ((enum == M.NOTIFY.FAILURE or enum == M.NOTIFY.SUCCESS_FAILURE) and status == STATUS.FAILURE)
  then
    local level = M.get_level_from_status(status)
    if format then
      vim.notify(format(task), level)
    else
      vim.notify(string.format("%s %s", status, task.name), level)
    end
    return true
  end
  return false
end

return M
