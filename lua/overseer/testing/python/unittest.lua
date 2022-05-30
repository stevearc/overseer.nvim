local files = require("overseer.files")
local tutils = require("overseer.testing.utils")

local M = {
  is_filename_test = function(self, filename)
    return filename:match("^test_.*%.py$")
  end,
  is_workspace_match = function(self, dirname)
    for _, fname in ipairs({ "setup.py", "setup.cfg", "pyproject.toml" }) do
      if files.exists(files.join(dirname, fname)) then
        return true
      end
    end
    return false
  end,
  run_test_dir = function(self, dirname)
    return {
      cmd = { "python", "-m", "unittest", "discover", "-s", dirname },
    }
  end,
  run_test_file = function(self, filename)
    return {
      cmd = { "python", "-m", "unittest", filename },
    }
  end,
  run_test_in_file = function(self, filename, test)
    local fullpath = vim.list_extend(vim.deepcopy(test.path), { test.name })
    local testpath = table.concat(fullpath, ".")
    local relfile = vim.fn.fnamemodify(filename, ":.:r")
    local dotted_path = relfile:gsub(files.sep, ".") .. "." .. testpath
    return {
      cmd = { "python", "-m", "unittest", dotted_path },
    }
  end,
  find_tests = function(self, bufnr)
    return tutils.get_tests_from_ts_query(
      bufnr,
      "python",
      "overseer_python_unittest",
      [[
(class_definition
  name: (identifier) @name (#lua-match? @name "^Test")) @group

(function_definition
  name: (identifier) @name (#lua-match? @name "^test_")) @test
]]
    )
  end,
}

return M
