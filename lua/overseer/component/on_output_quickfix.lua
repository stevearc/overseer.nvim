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
      desc = "If true, open the quickfix when task fails",
      type = "boolean",
      default = false,
    },
    close = {
      desc = "If true, close the quickfix when task succeeds",
      type = "boolean",
      default = false,
    },
    set_diagnostics = {
      desc = "If true, add the found items to diagnostics",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    return {
      on_complete = function(self, task, status)
        if status == STATUS.FAILURE then
          if params.open then
            vim.cmd("botright copen")
          end
        elseif params.close then
          vim.cmd("cclose")
        end
      end,
      on_pre_result = function(self, task)
        local lines = vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, true)
        vim.fn.setqflist({}, " ", {
          title = task.name,
          context = task.name,
          lines = lines,
          efm = params.errorformat,
        })
        if params.set_diagnostics then
          local items = vim.tbl_filter(function(item)
            return item.valid == 1
          end, vim.fn.getqflist())
          return {
            diagnostics = items,
          }
        end
      end,
    }
  end,
}
