-- Looks for a result value of 'diagnostics' that is a list of quickfix items
---@type overseer.ComponentFileDefinition
local comp = {
  desc = "If task result contains diagnostics, add them to the quickfix",
  params = {
    use_loclist = {
      desc = "If true, use the loclist instead of quickfix",
      type = "boolean",
      default = false,
    },
    close = {
      desc = "If true, close the quickfix when there are no diagnostics",
      type = "boolean",
      default = false,
    },
    open = {
      desc = "If true, open the quickfix when there are diagnostics",
      type = "boolean",
      default = false,
    },
    set_empty_results = {
      desc = "If true, overwrite the current quickfix even if there are no diagnostics",
      type = "boolean",
      default = false,
    },
    keep_focus = {
      desc = "If true, keep the current window focused when opening the quickfix",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    return {
      on_result = function(self, task, result)
        local diagnostics = result.diagnostics or {}
        local is_empty = vim.tbl_isempty(diagnostics)
        local conf
        local prev_context
        if params.use_loclist then
          prev_context = vim.fn.getloclist(0, { context = 1 }).context
          conf = {
            open_cmd = "lopen",
            close_cmd = "lclose",
          }
        else
          prev_context = vim.fn.getqflist({ context = 1 }).context
          conf = {
            open_cmd = "botright copen",
            close_cmd = "cclose",
          }
        end
        local what = {
          title = task.name,
          context = task.name,
          items = diagnostics,
        }
        local replace = prev_context == task.name
        local action = replace and "r" or " "
        if not replace and is_empty and not params.set_empty_results then
          return
        end

        if params.use_loclist then
          vim.fn.setloclist(0, {}, action, what)
        else
          vim.fn.setqflist({}, action, what)
        end

        if is_empty then
          if params.close then
            vim.cmd(conf.close_cmd)
          end
        elseif params.open then
          local winid = vim.api.nvim_get_current_win()
          vim.cmd(conf.open_cmd)
          if params.keep_focus then
            vim.api.nvim_set_current_win(winid)
          end
        end
      end,
    }
  end,
}

return comp
