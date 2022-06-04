local files = require("overseer.files")
local parser = require("overseer.parser")
local tutils = require("overseer.testing.utils")
local util = require("overseer.util")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local M = {
  name = "lua_plenary_busted",
  is_filename_test = function(self, filename)
    return filename:match("_spec%.lua$")
  end,
  is_workspace_match = function(self, dirname)
    for _, fname in ipairs({ "lua", ".luacheckrc", ".stylua.toml" }) do
      if files.exists(files.join(dirname, fname)) then
        return true
      end
    end
    return false
  end,
  cmd = { "nvim", "--headless" },
  run_test_dir = function(self, dirname)
    return {
      cmd = self.cmd,
      args = { "-c", string.format("PlenaryBustedDirectory %s", dirname) },
    }
  end,
  run_test_file = function(self, filename)
    return {
      cmd = self.cmd,
      args = { "-c", string.format("PlenaryBustedDirectory %s", filename) },
    }
  end,
  run_single_test = function(self, test)
    return self:run_test_file(test.filename)
  end,
  run_test_group = function(self, path)
    -- If running the top level path, that should actually re-run all tests
    if #path == 1 then
      return self:run_test_dir(vim.fn.getcwd(0))
    end
    local specifier = table.concat(path, ".")
    return {
      cmd = { "python", "-m", "unittest", "-b", "-v", specifier },
    }
  end,
  find_tests = function(self, bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    return tutils.get_tests_from_ts_query(
      bufnr,
      "lua",
      "overseer_lua_plenary_busted",
      [[
(function_call
  name: (identifier) @id (#eq? @id "describe")
  arguments: (arguments (string) @name)
) @group

(function_call
  name: (identifier) @id (#eq? @id "it")
  arguments: (arguments (string) @name)
) @test
]],
      function(item)
        item.filename = filename
        for i, v in ipairs(item.path) do
          item.path[i] = v:sub(2, -2)
        end
        local prefix = table.concat(item.path, " ")
        item.name = string.format("%s %s", prefix, item.name:sub(2, -2))
        item.path = nil
        return string.format("%s:%s", filename, item.name)
      end
    )
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
        return vim.fn.fnamemodify(candidate, ":p")
      end
    end
  end
  return filename
end

local add_id = function(item, ctx)
  item.id = string.format("%s:%s", ctx.default_values.filename, item.name)
end

local str_to_status = {
  Fail = TEST_STATUS.FAILURE,
  Success = TEST_STATUS.SUCCESS,
}
local status_field = {
  "status",
  function(val)
    return str_to_status[val]
  end,
}

M.parser = function()
  return {
    tests = {
      parser.extract({ append = false }, "^Testing:%s+(.+)$", { "filename", vim.trim }),
      parser.context(parser.loop(parser.parallel(
        parser.invert(parser.test("^Testing:")),
        parser.always(
          parser.extract(
            { postprocess = add_id },
            "^(Success)%s+||%s+(.+)$",
            status_field,
            { "name", vim.trim }
          )
        ),
        parser.always(parser.sequence(
          parser.extract(
            { append = false },
            "^(Fail)%s+||%s+(.+)$",
            status_field,
            { "name", vim.trim }
          ),
          parser.sequence(
            parser.parallel(
              -- After failure, take parse the error as a diagnostic
              parser.extract_nested(
                { append = false },
                "diagnostics",
                parser.sequence(
                  parser.extract(
                    { append = false },
                    "^%s+(.+):(%d+): (.+)$",
                    { "filename", M.fix_truncated_filename },
                    "lnum",
                    "text"
                  ),
                  parser.extract_multiline("^            (.+)$", "text")
                )
              ),
              -- After failure, parse all text as stdout
              parser.extract_multiline({ append = false }, "^            (.+)$", "text")
            ),
            -- Parse the stacktrace
            parser.skip_until("^%s+stack traceback:"),
            parser.extract_nested(
              { append = false },
              "stacktrace",
              parser.loop(
                parser.extract(
                  "^%s+(.+):(%d+): (.+)$",
                  { "filename", M.fix_truncated_filename },
                  "lnum",
                  "text"
                )
              )
            ),
            parser.append({
              postprocess = function(item, ctx)
                add_id(item, ctx)
                -- Only add the diagnostics if it's a failure within the test
                -- itself
                if item.diagnostics[1].filename ~= ctx.default_values.filename then
                  item.diagnostics = nil
                end
              end,
            })
          )
        ))
      ))),
    },
  }
end

return M
