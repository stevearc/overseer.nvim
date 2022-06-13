-- Looks for a result value of 'diagnostics' that is a list of quickfix items
return {
  description = "Put result diagnostics into the quickfix",
  params = {
    use_loclist = { type = "bool", optional = true },
  },
  constructor = function(params)
    return {
      on_result = function(self, task, status, result)
        if not result.diagnostics or vim.tbl_isempty(result.diagnostics) then
          return
        end
        if params.use_loclist then
          vim.fn.setloclist(0, result.diagnostics)
        else
          vim.fn.setqflist(result.diagnostics)
        end
      end,
    }
  end,
}
