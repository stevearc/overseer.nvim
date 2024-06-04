---@type overseer.ComponentFileDefinition
local comp = {
  desc = "If task result contains diagnostics, open trouble.nvim",
  params = {
    args = {
      desc = "Arguments passed to 'Trouble diagnostics open'",
      type = "list",
      subtype = {
        type = "string",
      },
      optional = true,
    },
    close = {
      desc = "If true, close Trouble when there are no diagnostics",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    return {
      on_result = function(self, task, result)
        local diagnostics = result.diagnostics or {}
        local is_empty = vim.tbl_isempty(diagnostics)

        if is_empty then
          if params.close then
            vim.cmd.Trouble({ args = { "diagnostics", "close" } })
          end
        else
          local args = { "diagnostics", "open" }
          if params.args then
            vim.list_extend(args, params.args)
          end
          vim.cmd.Trouble({ args = args })
        end
      end,
    }
  end,
}

return comp
