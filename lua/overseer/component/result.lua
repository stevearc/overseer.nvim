local constants = require("overseer.constants")
local util = require("overseer.util")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
local M = {}

M.exit_code_finalizer = {
  name = "exit_code",
  description = "Exit code finalizer",
  slot = SLOT.RESULT,
  constructor = function()
    return {
      on_exit = function(self, task, code)
        local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
        task:_set_result(status, {})
      end,
    }
  end,
}

-- Looks for a result value of 'quickfix' that is a list of quickfix items
M.quickfix_result = {
  name = "quickfix_result",
  description = "Put results into the quickfix",
  constructor = function()
    return {
      on_result = function(self, task, status, result)
        if not result.quickfix or vim.tbl_isempty(result.quickfix) then
          return
        end
        vim.fn.setqflist(result.quickfix)
      end,
    }
  end,
}

-- Looks for a result value of 'stacktrace' that is a list of quickfix items
M.quickfix_stacktrace = {
  name = "quickfix_stacktrace",
  description = "Put stacktrace results into the quickfix",
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

-- Looks for a result value of 'quickfix' that is a list of quickfix items
M.diagnostic_result = {
  name = "diagnostic_result",
  description = "Put quickfix results into diagnostics",
  params = {
    virtual_text = { type = "bool", optional = true },
    signs = { type = "bool", optional = true },
    underline = { type = "bool", optional = true },
  },
  constructor = function(params)
    local function remove_diagnostics(self)
      for _, bufnr in ipairs(self.bufnrs) do
        vim.diagnostic.reset(self.ns, bufnr)
      end
    end
    return {
      bufnrs = {},
      on_init = function(self, task)
        self.ns = vim.api.nvim_create_namespace(task.name)
      end,
      on_result = function(self, task, status, result)
        if not result.quickfix or vim.tbl_isempty(result.quickfix) then
          return
        end
        local grouped = util.tbl_group_by(result.quickfix, "filename")
        for filename, items in pairs(grouped) do
          local diagnostics = {}
          for _, item in ipairs(items) do
            table.insert(diagnostics, {
              message = item.text,
              severity = item.type == "W" and vim.diagnostic.severity.WARN
                or vim.diagnostic.severity.ERROR,
              lnum = (item.lnum or 1) - 1,
              end_lnum = item.end_lnum and (item.end_lnum - 1),
              col = item.col or 0,
              end_col = item.end_col,
              source = task.name,
            })
          end
          local bufnr = vim.fn.bufload(filename)
          if bufnr then
            if bufnr == 0 then
              bufnr = vim.api.nvim_get_current_buf()
            end
            vim.diagnostic.set(self.ns, bufnr, diagnostics, {
              virtual_text = params.virtual_text,
              signs = params.signs,
              underline = params.underline,
            })
            table.insert(self.bufnrs, bufnr)
          else
            vim.notify(string.format("Could not find file '%s'", filename), vim.log.levels.WARN)
          end
        end
      end,
      on_reset = function(self, task)
        remove_diagnostics(self)
        self.bufnrs = {}
      end,
      on_dispose = function(self, task)
        remove_diagnostics(self)
      end,
    }
  end,
}

return M
