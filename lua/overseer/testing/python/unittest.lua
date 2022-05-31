local files = require("overseer.files")
local tutils = require("overseer.testing.utils")

local M = {
  name = "python_unittest",
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
      cmd = { "python", "-m", "unittest", "discover", "-b", "-v", "-s", dirname },
      components = { { "result_exit_code", parser = "python_unittest" }, "default_test" },
    }
  end,
  run_test_file = function(self, filename)
    return {
      cmd = { "python", "-m", "unittest", "-b", "-v", filename },
      components = { { "result_exit_code", parser = "python_unittest" }, "default_test" },
    }
  end,
  run_test_in_file = function(self, filename, test)
    return {
      cmd = { "python", "-m", "unittest", "-b", "-v", test.id },
      components = { { "result_exit_code", parser = "python_unittest" }, "default_test" },
    }
  end,
  find_tests = function(self, bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local relfile = vim.fn.fnamemodify(filename, ":.:r")
    local path_to_file = vim.split(relfile, files.sep)
    return vim.tbl_map(
      function(item)
        item.fullpath = vim.list_extend(vim.deepcopy(path_to_file), item.path)
        local id = table.concat(item.fullpath, ".")
        if id ~= "" then
          id = id .. "." .. item.name
        else
          id = item.name
        end
        item.id = id
        return item
      end,
      tutils.get_tests_from_ts_query(
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
    )
  end,
}

return M
