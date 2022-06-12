-- Looks for a result value of 'stacktrace' that is a list of quickfix items
return {
  name = "on_result_stacktrace_quickfix",
  description = "Put result stacktrace into the quickfix",
  constructor = function()
    return {
      on_result = function(self, task, status, result)
        if not result.stacktrace or vim.tbl_isempty(result.stacktrace) then
          return
        end
        vim.fn.setqflist(result.stacktrace)
      end,
    }
  end,
}
