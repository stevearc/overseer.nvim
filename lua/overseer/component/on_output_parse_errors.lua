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
        vim.list_extend(
          self.items,
          vim.fn.getqflist({
            efm = params.errorformat,
            lines = lines,
          })
        )
      end,
      on_pre_result = function(self, task)
        return {
          diagnostics = self.items,
        }
      end,
    }
  end,
}
