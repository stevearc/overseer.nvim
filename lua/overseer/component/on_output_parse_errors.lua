return {
  desc = "Parse task output using 'errorformat'",
  params = {
    errorformat = {
      desc = "See :help errorformat",
      type = "string",
      optional = true,
    },
  },
  constructor = function(params)
    return {
      items = {},
      on_reset = function(self)
        self.items = {}
      end,
      on_output_lines = function(self, task, lines)
        local qf = vim.fn.getqflist({
          efm = params.errorformat,
          lines = lines,
        })
        if qf.items then
          vim.list_extend(self.items, qf.items)
        end
      end,
      on_pre_result = function(self, task)
        return {
          diagnostics = self.items,
        }
      end,
    }
  end,
}
