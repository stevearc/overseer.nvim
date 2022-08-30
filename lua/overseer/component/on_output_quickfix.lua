local constants = require("overseer.constants")
local STATUS = constants.STATUS

return {
  desc = "Set all task output into the quickfix (on complete)",
  params = {
    errorformat = {
      desc = "See :help errorformat",
      type = "string",
      optional = true,
    },
    open = {
      desc = "If true, open the quickfix when there are diagnostics",
      type = "boolean",
      default = false,
    },
    close = {
      desc = "If true, close the quickfix when task succeeds",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    return {
      on_complete = function(self, task, status)
        local lines = vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, true)
        vim.fn.setqflist({}, " ", {
          title = task.name,
          context = task.name,
          lines = lines,
          efm = params.errorformat,
        })
        if status == STATUS.FAILURE then
          if params.open then
            vim.cmd("botright copen")
          end
        elseif params.close then
          vim.cmd("cclose")
        end
      end,
    }
  end,
}
