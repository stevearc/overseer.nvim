local files = require("overseer.files")
local parser = require("overseer.parser")
local tutils = require("overseer.testing.utils")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local function shortpath(path)
  if path == vim.fn.getcwd(0) then
    return "."
  end
  return vim.fn.fnamemodify(path, ":.")
end

local M = {
  name = "lua_busted",
  is_workspace_match = function(self, dirname)
    for _, fname in ipairs({ ".busted" }) do
      if files.exists(files.join(dirname, fname)) then
        return true
      end
    end
    return false
  end,
  get_cmd = function(self)
    return { "busted" }
  end,
  run_test_dir = function(self, dirname)
    return {
      cmd = self:get_cmd(),
      args = { "-v", "--output=json", shortpath(dirname) },
    }
  end,
  run_test_file = function(self, filename)
    return {
      cmd = self:get_cmd(),
      args = { "-v", "--output=json", shortpath(filename) },
    }
  end,
  run_single_test = function(self, test)
    local fullpath = vim.list_extend(vim.deepcopy(test.path), { test.name })
    local identifier = table.concat(fullpath, " ")
    return {
      cmd = self:get_cmd(),
      args = {
        "-v",
        "--output=json",
        shortpath(test.filename),
        string.format("--filter=^%s$", identifier),
      },
    }
  end,
  run_test_group = function(self, path)
    local prefix = table.concat(path, " ")
    return {
      cmd = self:get_cmd(),
      args = { "-v", "--output=json", ".", string.format("--filter=^%s", prefix) },
    }
  end,
  find_tests = function(self, bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    return tutils.get_tests_from_ts_query(
      bufnr,
      "lua",
      "overseer_lua_busted",
      [[
(function_call
  name: (identifier) @func (#eq? @func "describe")
  arguments: (arguments (string) @name)
) @group

(function_call
  name: (identifier) @func (#eq? @func "it")
  arguments: (arguments (string) @name)
) @test
]],
      function(item)
        for i, v in ipairs(item.path) do
          item.path[i] = v:sub(2, -2)
        end
        item.name = item.name:sub(2, -2)
        local fullpath = vim.list_extend(vim.deepcopy(item.path), { item.name })
        -- We have to merge all of the parent 'describe' groups because that's
        -- how the test output supplies them
        item.path = { table.concat(item.path, " ") }
        return string.format("%s:%s", filename, table.concat(fullpath, " "))
      end
    )
  end,
}

M.parser = function()
  return parser.custom({
    add_item = function(self, data, status)
      local filename = vim.fn.fnamemodify(data.trace.source:sub(2), ":p")
      local text = data.trace.message
      if text == data.element.name then
        text = nil
      elseif type(text) == "table" then
        text = text.message
      end
      local diagnostics
      if status == TEST_STATUS.FAILURE then
        local fname, lnum, msg = text:match("^(.+):(%d+): (.*)$")
        diagnostics = { { filename = fname, lnum = lnum, text = msg } }
      end
      local stacktrace
      if data.isError then
        stacktrace = {}
        for line in vim.gsplit(data.trace.traceback, "\n") do
          local fname, lnum, msg = line:match("^(.+):(%d+): (.*)$")
          if fname then
            table.insert(stacktrace, { filename = fname, lnum = lnum, text = msg })
          end
        end
      end
      local result = {
        id = string.format("%s:%s", filename, data.name),
        name = data.element.name,
        path = { data.name:sub(1, -string.len(data.element.name) - 2) },
        status = status,
        filename = filename,
        duration = data.element.duration,
        text = text,
        diagnostics = diagnostics,
        stacktrace = stacktrace,
      }
      if not self.results.tests then
        self.results.tests = {}
      end
      table.insert(self.results.tests, result)
    end,
    _ingest = function(self, lines)
      for _, line in ipairs(lines) do
        local ok, data = pcall(vim.json.decode, line)
        if ok then
          for _, test_data in ipairs(data.successes) do
            self:add_item(test_data, TEST_STATUS.SUCCESS)
          end
          for _, test_data in ipairs(data.pendings) do
            self:add_item(test_data, TEST_STATUS.SKIPPED)
          end
          for _, test_data in ipairs(data.failures) do
            self:add_item(test_data, TEST_STATUS.FAILURE)
          end
          for _, test_data in ipairs(data.errors) do
            self:add_item(test_data, TEST_STATUS.FAILURE)
          end
        end
      end
    end,
  })
end

return M
