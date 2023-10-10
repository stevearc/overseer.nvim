local util = require("overseer.util")

local type_to_severity = {
  e = vim.diagnostic.severity.ERROR,
  E = vim.diagnostic.severity.ERROR,
  w = vim.diagnostic.severity.WARN,
  W = vim.diagnostic.severity.WARN,
  n = vim.diagnostic.severity.INFO,
  N = vim.diagnostic.severity.INFO,
  i = vim.diagnostic.severity.INFO,
  I = vim.diagnostic.severity.INFO,
}

-- Looks for a result value of 'diagnostics' that is a list of quickfix items
---@type overseer.ComponentFileDefinition
local comp = {
  desc = "If task result contains diagnostics, display them",
  params = {
    virtual_text = {
      desc = "Override the default diagnostics.virtual_text setting",
      type = "boolean",
      optional = true,
    },
    signs = {
      desc = "Override the default diagnostics.signs setting",
      type = "boolean",
      optional = true,
    },
    underline = {
      desc = "Override the default diagnostics.underline setting",
      type = "boolean",
      optional = true,
    },
    remove_on_restart = {
      desc = "Remove diagnostics when task restarts",
      type = "boolean",
      optional = true,
    },
  },
  constructor = function(params)
    local function remove_diagnostics(self)
      for _, bufnr in ipairs(self.bufnrs) do
        vim.diagnostic.reset(self.ns, bufnr)
      end
      self.bufnrs = {}
    end
    return {
      bufnrs = {},
      on_init = function(self, task)
        self.ns = vim.api.nvim_create_namespace(task.name)
      end,
      on_result = function(self, task, result)
        remove_diagnostics(self)
        if not result.diagnostics or vim.tbl_isempty(result.diagnostics) then
          return
        end
        -- QF items might have bufnr instead of filename, but we need filename for grouping
        for _, diag in ipairs(result.diagnostics) do
          if not diag.filename and diag.bufnr and diag.bufnr ~= 0 then
            diag.filename = vim.api.nvim_buf_get_name(diag.bufnr)
          end
        end
        local grouped = util.tbl_group_by(result.diagnostics, "filename")
        for filename, items in pairs(grouped) do
          local diagnostics = {}
          for _, item in ipairs(items) do
            table.insert(diagnostics, {
              message = item.text,
              severity = type_to_severity[item.type] or vim.diagnostic.severity.ERROR,
              lnum = (item.lnum or 1) - 1,
              end_lnum = item.end_lnum and (item.end_lnum - 1),
              col = item.col or 0,
              end_col = item.end_col,
              source = task.name,
            })
          end
          local bufnr = vim.fn.bufadd(filename)
          vim.diagnostic.set(self.ns, bufnr, diagnostics, {
            virtual_text = params.virtual_text,
            signs = params.signs,
            underline = params.underline,
          })
          table.insert(self.bufnrs, bufnr)
          if not vim.api.nvim_buf_is_loaded(bufnr) then
            util.set_bufenter_callback(bufnr, "diagnostics_show", function()
              vim.diagnostic.show(self.ns, bufnr)
            end)
          end
        end
      end,
      on_reset = function(self, task)
        if params.remove_on_restart then
          remove_diagnostics(self)
        end
      end,
      on_dispose = function(self, task)
        remove_diagnostics(self)
      end,
    }
  end,
}

return comp
