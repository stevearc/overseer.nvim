local data = require("overseer.testing.data")
local panel = require("overseer.testing.panel")
local utils = require("overseer.testing.utils")
local M = {}

M.create_commands = function()
  vim.api.nvim_create_user_command("OverseerTest", function()
    M.test_dir()
  end, {
    desc = "Run tests for the current project",
  })
  vim.api.nvim_create_user_command("OverseerTestFile", function()
    M.test_file()
  end, {
    desc = "Run tests for the current file",
  })
  vim.api.nvim_create_user_command("OverseerTestNearest", function()
    M.test_nearest()
  end, {
    desc = "Run the nearest test in the current test file",
  })
  vim.api.nvim_create_user_command("OverseerToggleTestPanel", function()
    panel.toggle()
  end, {
    desc = "Toggle the test panel",
  })
end

M.integrations = {}

local builtin_tests = { "python.unittest" }
M.register_builtin = function()
  for _, mod in ipairs(builtin_tests) do
    table.insert(M.integrations, require(string.format("overseer.testing.%s", mod)))
  end
end

M.get_integrations_for_dir = function(dirname)
  local ret = {}
  for _, integration in ipairs(M.integrations) do
    if integration:is_workspace_match(dirname) then
      table.insert(ret, integration)
    end
  end
  return ret
end

M.get_integrations_for_buf = function(bufnr)
  bufnr = bufnr or 0
  local ret = {}
  for _, integration in ipairs(M.integrations) do
    local tests = integration:find_tests(bufnr)
    if not vim.tbl_isempty(tests) then
      table.insert(ret, integration)
    end
  end
  return ret
end

M.test_dir = function(dirname)
  dirname = dirname or vim.fn.getcwd(0)
  local integrations = M.get_integrations_for_dir(dirname)
  if vim.tbl_isempty(integrations) then
    vim.cmd([[TestSuite]])
    return
  end
  data.reset_dir_results(dirname)
  for _, v in ipairs(integrations) do
    utils.create_and_start_task(v:run_test_dir(dirname))
  end
  data.touch()
end

M.test_file = function(bufnr)
  bufnr = bufnr or 0
  local integrations = M.get_integrations_for_buf(bufnr)
  if vim.tbl_isempty(integrations) then
    vim.cmd([[TestFile]])
    return
  end
  for _, v in ipairs(integrations) do
    for _, test in ipairs(v:find_tests(bufnr)) do
      data.reset_test_status(test.id)
    end
    utils.create_and_start_task(v:run_test_file(vim.api.nvim_buf_get_name(bufnr)))
  end
  data.touch()
end

M.test_nearest = function(bufnr, lnum)
  bufnr = bufnr or 0
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  local ran_any = false
  local integrations = M.get_integrations_for_buf(bufnr)
  if vim.tbl_isempty(integrations) then
    vim.cmd([[TestNearest]])
    return
  end
  for _, v in ipairs(M.get_integrations_for_buf(bufnr)) do
    local tests = v:find_tests(bufnr)
    local test = utils.find_nearest_test(tests, lnum)
    if test then
      ran_any = true
      data.reset_test_status(test.id)
      utils.create_and_start_task(v:run_test_in_file(vim.api.nvim_buf_get_name(bufnr), test))
    end
  end
  data.touch()
  if not ran_any then
    vim.notify("Could not find nearest test", vim.log.levels.WARN)
  end
end

return M
