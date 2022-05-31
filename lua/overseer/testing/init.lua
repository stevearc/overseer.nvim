local data = require("overseer.testing.data")
local integrations = require("overseer.testing.integrations")
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

M.register_builtin = integrations.register_builtin

M.test_dir = function(dirname)
  dirname = dirname or vim.fn.getcwd(0)
  local integ = integrations.get_for_dir(dirname)
  if vim.tbl_isempty(integ) then
    vim.cmd([[TestSuite]])
    return
  end
  data.reset_dir_results(dirname)
  for _, v in ipairs(integ) do
    utils.create_and_start_task(v.name, v:run_test_dir(dirname))
  end
  data.touch()
end

M.test_file = function(bufnr)
  bufnr = bufnr or 0
  local integ = integrations.get_for_buf(bufnr)
  if vim.tbl_isempty(integ) then
    vim.cmd([[TestFile]])
    return
  end
  for _, v in ipairs(integ) do
    for _, test in ipairs(v:find_tests(bufnr)) do
      data.reset_test_status(test.id)
    end
    utils.create_and_start_task(v.name, v:run_test_file(vim.api.nvim_buf_get_name(bufnr)))
  end
  data.touch()
end

M.test_nearest = function(bufnr, lnum)
  bufnr = bufnr or 0
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  local ran_any = false
  local integ = integrations.get_for_buf(bufnr)
  if vim.tbl_isempty(integ) then
    vim.cmd([[TestNearest]])
    return
  end
  for _, v in ipairs(integrations.get_for_buf(bufnr)) do
    local tests = v:find_tests(bufnr)
    local test = utils.find_nearest_test(tests, lnum)
    if test then
      ran_any = true
      data.reset_test_status(test.id)
      utils.create_and_start_task(
        v.name,
        v:run_test_in_file(vim.api.nvim_buf_get_name(bufnr), test)
      )
    end
  end
  data.touch()
  if not ran_any then
    vim.notify("Could not find nearest test", vim.log.levels.WARN)
  end
end

return M
