local overseer = require("overseer")
local constants = require("overseer.constants")
local files = require("overseer.files")
local parser = require("overseer.parser")
local util = require("overseer.util")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
local M = {}

M.busted_test = {
  name = "busted test (plenary)",
  tags = { overseer.TAG.TEST },
  params = { filename = {} },
  condition = {
    filetype = "lua",
  },
  builder = function(self, params)
    return {
      cmd = { "nvim", "--headless", "-c", "PlenaryBustedFile " .. params.filename },
      components = { "plenary_busted_test_parser", "default_test" },
    }
  end,
}

M.fix_truncated_filename = function(filename)
  if not filename:match("^%.%.%.") then
    return filename
  end
  local cwd = vim.fn.getcwd(0)
  local dirname = vim.fn.fnamemodify(cwd, ":p:h:t")
  local pieces = vim.split(string.sub(filename, 4), files.sep)
  for i, v in ipairs(pieces) do
    if v == dirname then
      local candidate = table.concat(util.tbl_slice(pieces, i + 1), files.sep)
      if files.exists(candidate) then
        return candidate
      end
    end
  end
  return filename
end

M.plenary_busted_test_parser = {
  parser.skip_until("^Fail"),
  parser.extract(
    { append = false },
    "^%s+(.+):(%d+): (.+)$",
    { "filename", M.fix_truncated_filename },
    "lnum",
    "text"
  ),
  parser.extract_multiline("^            (.+)$", "text"),
}

M.plenary_busted_test_parser_defn = {
  name = "plenary_busted_test_parser",
  description = "Parse busted test output from plenary.nvim",
  slot = SLOT.RESULT,
  constructor = function()
    return {
      parser = overseer.parser.new({
        diagnostics = M.plenary_busted_test_parser,
      }),
      on_reset = function(self)
        self.parser:reset()
      end,
      on_output_lines = function(self, task, lines)
        self.parser:ingest(lines)
      end,
      on_exit = function(self, task, code)
        local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
        task:_set_result(status, self.parser:get_result())
      end,
    }
  end,
}

return M
