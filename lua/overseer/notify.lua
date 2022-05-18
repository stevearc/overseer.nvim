local constants = require("overseer.constants")
local STATUS = constants.STATUS
local M = {}

M.NOTIFY = {
  NEVER = 'never',
  SUCCESS_FAILURE = 'success_failure',
  ALWAYS = 'always',
  SUCCESS = 'success',
  FAILURE = 'failure',
}

M.new_on_result_notifier = function(opts)
  opts = opts or {}
  vim.validate({when = { opts.when, 's', true}})
  return {
    when = opts.when or M.NOTIFY.SUCCESS_FAILURE,
    on_result = function(self, task, status)
      M.vim_notify_from_status(task, status, self.when)
    end
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

M.vim_notify_from_status = function(task, status, enum)
  enum = enum or M.NOTIFY.ALWAYS
  if enum == M.NOTIFY.ALWAYS or ((enum == M.NOTIFY.SUCCESS or enum == M.NOTIFY.SUCCESS_FAILURE) and status == STATUS.SUCCESS) or ((enum == M.NOTIFY.FAILURE or enum == M.NOTIFY.SUCCESS_FAILURE) and status == STATUS.FAILURE) then
    local level = M.get_level_from_status(status)
    vim.notify(string.format("%s %s", status, task.name), level)
    return true
  end
  return false
end

return M
