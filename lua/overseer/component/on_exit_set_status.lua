local constants = require("overseer.constants")
local STATUS = constants.STATUS

return {
  desc = "Sets final task status based on exit code",
  params = {
    success_codes = {
      desc = "Additional exit codes to consider as success",
      type = "list",
      optional = true,
      subtype = { type = "integer" },
    },
  },
  constructor = function(params)
    local success_codes = vim.tbl_map(function(code)
      return tonumber(code)
    end, params.success_codes or {})
    table.insert(success_codes, 0)
    return {
      on_exit = function(self, task, code)
        local status = vim.tbl_contains(success_codes, code) and STATUS.SUCCESS or STATUS.FAILURE
        task:finalize(status)
      end,
    }
  end,
}
