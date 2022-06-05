local files = require("overseer.files")
local parser = require("overseer.parser")
local tutils = require("overseer.testing.utils")
local util = require("overseer.util")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local M = {
  name = "ruby_rspec",
  is_workspace_match = function(self, dirname)
    for _, fname in ipairs({ "Gemfile" }) do
      if files.exists(files.join(dirname, fname)) then
        return true
      end
    end
    return false
  end,
  get_cmd = function(self)
    return { "bundle", "exec", "rspec" }
  end,
  run_test_dir = function(self, dirname)
    return {
      cmd = self:get_cmd(),
      args = { "--exclude-pattern", "bundle/**/*.rb", "--format=json", dirname },
    }
  end,
  run_test_file = function(self, filename)
    return {
      cmd = self:get_cmd(),
      args = { "--format=json", filename },
    }
  end,
  run_single_test = function(self, test)
    return {
      cmd = self:get_cmd(),
      args = { "--format=json", "-e", test.id },
    }
  end,
  run_test_group = function(self, path)
    return {
      cmd = self:get_cmd(),
      args = { "--format=json", "-e", table.concat(path, " ") },
    }
  end,
  find_tests = function(self, bufnr)
    return tutils.get_tests_from_ts_query(
      bufnr,
      "ruby",
      "overseer_ruby_rspec",
      [[
(call
  method: (identifier) @ident (#eq? @ident "describe")
  arguments: (argument_list (constant) @name)) @group

(call
  method: (identifier) @ident (#eq? @ident "it")
  arguments: (argument_list (string (string_content) @name))) @test
]],
      function(item)
        local fullpath = vim.list_extend(vim.deepcopy(item.path), { item.name })
        return table.concat(fullpath, " ")
      end
    )
  end,
}

local str_to_status = {
  passed = TEST_STATUS.SUCCESS,
  failed = TEST_STATUS.FAILURE,
  pending = TEST_STATUS.SKIPPED,
}

M.parser = function()
  return parser.custom({
    add_item = function(self, data)
      local text = data.pending_message
      local stacktrace
      if data.exception then
        stacktrace = {}
        for _, line in ipairs(data.exception.backtrace) do
          local fname, lnum, msg = line:match("^(.+):(%d+):(.*)$")
          if
            fname
            -- Trim out useless parts of the stacktrace
            and not fname:match("gems/rspec%-expectations%-%d+.%d+.%d+")
            and not fname:match("gems/rspec%-core%-%d+.%d+.%d+")
            and not fname:match("gems/rspec%-support%-%d+.%d+.%d+")
          then
            table.insert(stacktrace, {
              filename = fname,
              lnum = lnum,
              text = msg,
            })
          end
        end
        text = util.remove_ansi(
          string.format("%s\n%s", data.exception.class, data.exception.message)
        )
      end
      if text == vim.NIL then
        text = nil
      end
      local result = {
        id = data.full_description,
        name = data.description,
        path = { data.full_description:sub(1, -string.len(data.description) - 2) },
        status = str_to_status[data.status],
        filename = data.file_path,
        lnum = data.line_number,
        duration = data.run_time,
        text = text,
        diagnostics = nil,
        stacktrace = stacktrace,
      }
      -- print(string.format("esult: %s", vim.inspect(result)))
      if not self.results.tests then
        self.results.tests = {}
      end
      table.insert(self.results.tests, result)
    end,
    _ingest = function(self, lines)
      for _, line in ipairs(lines) do
        local ok, data = pcall(vim.json.decode, line)
        if ok then
          for _, test_data in ipairs(data.examples) do
            self:add_item(test_data)
          end
        end
      end
    end,
  })
end

return M
