local action_util = require("overseer.action_util")
local config = require("overseer.config")
local data = require("overseer.testing.data")
local integrations = require("overseer.testing.integrations")
local panel = require("overseer.testing.panel")
local utils = require("overseer.testing.utils")
local TEST_STATUS = data.TEST_STATUS
local M = {}

M._test_dir = function(_params)
  M.test_dir()
end

M._test_file = function(_params)
  M.test_file()
end

M._test_nearest = function(_params)
  M.test_nearest()
end

M._test_last = function(_params)
  M.test_last()
end

M._test_action = function(_params)
  M.test_action()
end

M._rerun_failed = function(_params)
  M.rerun_failed()
end

M._toggle = function(_params)
  panel.toggle()
end

M.test_dir = function(dirname)
  dirname = dirname or vim.fn.getcwd(0)
  local integ = integrations.get_for_dir(dirname)
  if vim.tbl_isempty(integ) then
    if config.testing.vim_test_fallback and vim.fn.exists(":TestSuite") == 2 then
      vim.cmd([[TestSuite]])
    end
    return
  end
  for _, v in ipairs(integ) do
    integrations.create_and_start_task(v, v:run_test_dir(dirname), { dirname = dirname })
  end
  data.touch()
end

M.test_file = function(bufnr)
  bufnr = bufnr or 0
  local integ = integrations.get_for_buf(bufnr)
  if vim.tbl_isempty(integ) then
    if config.testing.vim_test_fallback and vim.fn.exists(":TestFile") == 2 then
      vim.cmd([[TestFile]])
    end
    return
  end
  for _, v in ipairs(integ) do
    local tests = v:find_tests(bufnr)
    integrations.create_and_start_task(
      v,
      v:run_test_file(vim.api.nvim_buf_get_name(bufnr)),
      { tests = tests }
    )
  end
  data.touch()
end

M.test_nearest = function(bufnr, lnum)
  bufnr = bufnr or 0
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  local ran_any = false
  local integ = integrations.get_for_buf(bufnr)
  if vim.tbl_isempty(integ) then
    if config.testing.vim_test_fallback and vim.fn.exists(":TestNearest") == 2 then
      vim.cmd([[TestNearest]])
    end
    return
  end
  for _, v in ipairs(integrations.get_for_buf(bufnr)) do
    local tests = v:find_tests(bufnr)
    local test = utils.find_nearest_test(tests, lnum)
    if test then
      ran_any = true
      integrations.create_and_start_task(v, v:run_single_test(test), { tests = { test } })
    end
  end
  data.touch()
  if not ran_any then
    vim.notify("Could not find nearest test", vim.log.levels.WARN)
  end
end

M.test_last = function()
  if not integrations.rerun_last_task() then
    vim.notify("No test has been run yet", vim.log.levels.WARN)
  end
end

M.rerun_failed = function()
  local all_failed = vim.tbl_filter(function(t)
    return t.status == TEST_STATUS.FAILURE
  end, data.get_results())
  local reset_all = true
  for _, test in ipairs(all_failed) do
    local integ = integrations.get(test.integration_id)
    -- On the first task, reset ALL of the failed tasks so we see them all as
    -- running immediately
    local to_reset = reset_all and all_failed or { test }
    integrations.create_and_start_task(integ, integ:run_single_test(test), { tests = to_reset })
    reset_all = false
  end
end

M.test_action = function()
  local bufnr = 0
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local p = panel.get_panel(bufnr)
  if p then
    p:run_action()
  else
    for _, v in ipairs(integrations.get_for_buf(bufnr)) do
      local tests = v:find_tests(bufnr)
      local test = utils.find_nearest_test(tests, lnum)
      if test then
        test = data.get_result(test.id) or data.normalize_test(v.id, test)
        local entry = { type = "test", test = test }
        action_util.run_action({
          actions = config.testing.actions,
          prompt = test.name,
          post_action = function()
            data.touch()
          end,
        }, entry)
        return
      end
    end
  end
end

return M
