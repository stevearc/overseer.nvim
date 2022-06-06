local files = require("overseer.files")
local parser = require("overseer.parser")
local tutils = require("overseer.testing.utils")
local util = require("overseer.util")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local function gen_output_file()
  return files.gen_random_filename("cache", "jest_output_%d.json")
end

local M = {
  name = "javascript_jest",
  is_workspace_match = function(self, dirname)
    if files.exists("package.json") then
      local ok, data = pcall(files.load_json_file, "package.json")
      if ok and data.devDependencies then
        for k in pairs(data.devDependencies) do
          if k == "jest" then
            return true
          end
        end
      end
    end
    return false
  end,
  get_cmd = function(self)
    if files.exists("yarn.lock") then
      return { "yarn", "run", "jest" }
    else
      return { "npx", "jest" }
    end
  end,
  run_test_dir = function(self, dirname)
    local output_file = gen_output_file()
    return {
      cmd = self:get_cmd(),
      args = { "--json", string.format("--outputFile=%s", output_file), dirname },
      metadata = { output_file = output_file },
    }
  end,
  run_test_file = function(self, filename)
    local output_file = gen_output_file()
    return {
      cmd = self:get_cmd(),
      args = { "--json", string.format("--outputFile=%s", output_file), filename },
      metadata = { output_file = output_file },
    }
  end,
  run_single_test = function(self, test)
    local output_file = gen_output_file()
    return {
      cmd = self:get_cmd(),
      args = {
        "--json",
        string.format("--outputFile=%s", output_file),
        test.filename,
        "-t",
        string.format("^%s$", test.id),
      },
      metadata = { only_test = test.id, output_file = output_file },
    }
  end,
  run_test_group = function(self, path)
    local specifier = table.concat(path, " ")
    local output_file = gen_output_file()
    return {
      cmd = self:get_cmd(),
      args = {
        "--json",
        string.format("--outputFile=%s", output_file),
        "-t",
        string.format("^%s", specifier),
      },
      metadata = { ignore_skipped = true, output_file = output_file },
    }
  end,
  find_tests = function(self, bufnr)
    return tutils.get_tests_from_ts_query(
      bufnr,
      "javascript",
      "overseer_javascript_jest",
      [[
; describe("Unit test")
(call_expression
  function: (identifier) @method (#eq? @method "describe")
  arguments: (arguments
    (string
      (string_fragment) @name))
) @group

; test("this test")
(call_expression
  function: (identifier) @method (#any-of? @method "test" "it")
  arguments: (arguments
    (string
      (string_fragment) @name))
) @test

; test.skip("Unit test")
(call_expression
  function: (member_expression
    object: (identifier) @method (#eq? @method "describe")
    property: (property_identifier) @modifier (#any-of? @modifier "skip" "todo")
  )
  arguments: (arguments
    (string
      (string_fragment) @name))
) @group

; test.skip("this test")
(call_expression
  function: (member_expression
    object: (identifier) @method (#any-of? @method "test" "it")
    property: (property_identifier) @modifier (#any-of? @modifier "skip" "todo")
  )
  arguments: (arguments
    (string
      (string_fragment) @name))
) @test

; describe.each([])("Test suite")
(call_expression
  function: (call_expression
    function: (member_expression
      object: (identifier) @method (#eq? @method "describe")
      property: (property_identifier) @modifier (#eq? @modifier "each")
    )
  )
  arguments: (arguments
    (string
      (string_fragment) @name))
) @group

; describe.each([])("this test")
(call_expression
  function: (call_expression
    function: (member_expression
      object: (identifier) @method (#any-of? @method "test" "it")
      property: (property_identifier) @modifier (#eq? @modifier "each")
    )
  )
  arguments: (arguments
    (string
      (string_fragment) @name))
) @test
]],
      function(item)
        local fullpath = vim.list_extend(vim.deepcopy(item.path), { item.name })
        local id = table.concat(fullpath, " ")
        return id
      end
    )
  end,
}

local str_to_status = {
  passed = TEST_STATUS.SUCCESS,
  pending = TEST_STATUS.SKIPPED,
  failed = TEST_STATUS.FAILURE,
}

M.parser = function(task)
  return parser.custom({
    process = function(self, result, assertion_result, only_test, ignore_skipped)
      local stacktrace
      local diagnostics
      local found_expected = false
      local diag_text = {}
      local text_lines = {}
      local prev = ""
      for _, message in ipairs(assertion_result.failureMessages) do
        for line in vim.gsplit(message, "\n") do
          line = util.remove_ansi(line)
          table.insert(text_lines, line)
          if line:match("^Expected:") then
            found_expected = true
          end
          local line_txt, fname, lnum, col = line:match("%s+(at%s.*)%s%((.+):(%d+):(%d+)%)$")
          if fname then
            if found_expected then
              diagnostics = {
                {
                  filename = fname,
                  lnum = tonumber(lnum),
                  col = tonumber(col),
                },
              }
            else
              if not stacktrace then
                line_txt = prev
              end
              stacktrace = stacktrace or {}
              table.insert(stacktrace, {
                filename = fname,
                lnum = tonumber(lnum),
                col = tonumber(col),
                text = line_txt,
              })
            end
          elseif found_expected then
            table.insert(diag_text, line)
          end
          prev = line
        end
      end
      if found_expected then
        diagnostics[1].text = table.concat(diag_text, "\n")
      end
      local duration = assertion_result.duration
      if duration == vim.NIL then
        duration = nil
      else
        duration = duration / 1000
      end
      local status = str_to_status[assertion_result.status]
      if
        (not only_test or only_test == assertion_result.fullName)
        and (not ignore_skipped or status ~= TEST_STATUS.SKIPPED)
      then
        table.insert(self.results.tests, {
          filename = result.name,
          duration = duration,
          status = status,
          id = assertion_result.fullName,
          name = assertion_result.title,
          path = assertion_result.ancestorTitles,
          text = table.concat(text_lines, "\n"),
          stacktrace = stacktrace,
          diagnostics = diagnostics,
        })
      end
    end,
    get_result = function(self)
      if not task.metadata.output_file then
        vim.api.nvim_err_writeln(
          string.format("Task had no output_file in metadata: %s", vim.inspect(task.metadata))
        )
        return
      end
      local ok, results = pcall(files.load_json_file, task.metadata.output_file)
      vim.loop.fs_unlink(task.metadata.output_file)
      if ok and results then
        self.results.tests = {}
        for _, result in ipairs(results.testResults) do
          for _, assertion_result in ipairs(result.assertionResults) do
            self:process(
              result,
              assertion_result,
              task.metadata.only_test,
              task.metadata.ignore_skipped
            )
          end
        end
      end
      return self.results
    end,
    _ingest = function(self, lines) end,
  })
end

return M
