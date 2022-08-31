return {
  desc = "Set all task output into the quickfix (on complete)",
  params = {
    errorformat = {
      desc = "See :help errorformat",
      type = "string",
      optional = true,
    },
    open = {
      desc = "If true, open the quickfix when any items found",
      type = "boolean",
      default = false,
    },
    close = {
      desc = "If true, close the quickfix when no items found",
      type = "boolean",
      default = false,
    },
    items_only = {
      desc = "If true, only show valid matches in the quickfix",
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
      on_complete = function(self, task, status) end,
      on_pre_result = function(self, task)
        local lines = vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, true)
        local prev_context = vim.fn.getqflist({ context = 1 }).context
        local replace = prev_context == task.name
        local action = replace and "r" or " "
        local what = {
          title = task.name,
          context = task.name,
          lines = lines,
          efm = params.errorformat,
        }
        vim.fn.setqflist({}, action, what)

        local items = vim.tbl_filter(function(item)
          return item.valid == 1
        end, vim.fn.getqflist())
        if vim.tbl_isempty(items) then
          if params.close then
            vim.cmd("cclose")
          end
        elseif params.open then
          vim.cmd("botright copen")
        end

        if params.items_only then
          vim.fn.setqflist({}, "r", {
            title = task.name,
            context = task.name,
            items = items,
          })
        end

        if params.set_diagnostics then
          return {
            diagnostics = items,
          }
        end
      end,
    }
  end,
}
