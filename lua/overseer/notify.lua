local M = {}

M.NOTIFY = {
  NEVER = 'never',
  ALWAYS = 'always',
  SUCCESS = 'success',
  FAILURE = 'failure',
}

M.new_on_exit_notifier = function(opts)
  opts = opts or {}
  vim.validate({when = { opts.when, 's', true}})
  return {
    config = opts.when or M.NOTIFY.ALWAYS,
    on_exit = function(self, task, code)
      M.vim_notify_from_code(task, code, self.config)
    end
  }
end

M.vim_notify_from_code = function(task, code, enum)
  enum = enum or M.NOTIFY.ALWAYS
  if enum == M.NOTIFY.ALWAYS or (enum == M.NOTIFY.SUCCESS and code == 0) or (enum == M.NOTIFY.FAILURE and code ~= 0) then
    local level = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
    local msg = code == 0 and "COMPLETED" or "FAILED"
    vim.notify(string.format("%s %s", task.name, msg), level)
    return true
  end
  return false
end

return M
