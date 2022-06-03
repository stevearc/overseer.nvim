local Enum = require("overseer.enum")
local integrations = require("overseer.testing.integrations")
local util = require("overseer.util")
local M = {}

local TEST_STATUS = Enum.new({ "NONE", "RUNNING", "SUCCESS", "FAILURE", "SKIPPED" })

M.TEST_STATUS = TEST_STATUS

local callbacks = {}

local function do_callbacks()
  for _, cb in ipairs(callbacks) do
    cb()
  end
end

M.results = {}

local Summary = {}

function Summary:get_status()
  if self[TEST_STATUS.FAILURE] > 0 then
    return TEST_STATUS.FAILURE
  elseif self[TEST_STATUS.RUNNING] > 0 then
    return TEST_STATUS.RUNNING
  elseif self[TEST_STATUS.SUCCESS] > 0 then
    return TEST_STATUS.SUCCESS
  elseif self[TEST_STATUS.SKIPPED] > 0 then
    return TEST_STATUS.SKIPPED
  else
    return TEST_STATUS.NONE
  end
end

local function new_summary()
  local ret = setmetatable({}, { __index = Summary })
  for _, v in ipairs(TEST_STATUS.values) do
    ret[v] = 0
  end
  return ret
end

local function update_summaries(summaries, result)
  local root = summaries["_"]
  root[result.status] = 1 + root[result.status]
  local cur = summaries
  for _, path in ipairs(result.path) do
    if not cur[path] then
      cur[path] = new_summary()
    end
    cur = cur[path]
    cur[result.status] = 1 + cur[result.status]
  end
end

local function compare_tests(a, b)
  for i = 1, math.min(#a.path, #b.path) do
    local ap = a.path[i]
    local bp = b.path[i]
    if ap ~= bp then
      return ap < bp
    end
  end
  if #a.path ~= #b.path then
    return #a.path < #b.path
  end
  return a.name < b.name
end

local cached_workspace_results
M.get_workspace_results = function()
  if cached_workspace_results then
    return cached_workspace_results
  end
  local results = vim.tbl_values(M.results)
  table.sort(results, compare_tests)

  local root = new_summary()
  local summaries = { ["_"] = root }
  for _, v in ipairs(results) do
    update_summaries(summaries, v)
  end

  cached_workspace_results = {
    tests = results,
    summaries = summaries,
  }
  return cached_workspace_results
end

local function add_workspace_result(result)
  if not cached_workspace_results then
    return
  end
  local inserted = false
  for i, v in ipairs(cached_workspace_results.tests) do
    if v.id == result.id then
      cached_workspace_results.tests[i] = result
      inserted = true
      break
    elseif compare_tests(result, v) then
      table.insert(cached_workspace_results.tests, i, result)
      inserted = true
      break
    end
  end
  if not inserted then
    table.insert(cached_workspace_results.tests, result)
  end
  update_summaries(cached_workspace_results.summaries, result)
end

M.add_callback = function(cb)
  table.insert(callbacks, cb)
end

M.remove_callback = function(cb)
  for i, v in ipairs(callbacks) do
    if v == cb then
      table.remove(callbacks, i)
      return
    end
  end
end

local reset_on_next_results = false
local test_ns = vim.api.nvim_create_namespace("OverseerTestsErrors")
local sign_group = "OverseerTestSigns"
local diagnostics_bufnrs = {}
local sign_bufnrs = {}
local function remove_diagnostics()
  for _, bufnr in ipairs(diagnostics_bufnrs) do
    vim.diagnostic.reset(test_ns, bufnr)
  end
  for bufnr in pairs(sign_bufnrs) do
    vim.fn.sign_unplace(sign_group, { buffer = bufnr })
  end
  diagnostics_bufnrs = {}
  sign_bufnrs = {}
end

M.clear_results = function()
  M.results = {}
  remove_diagnostics()
  cached_workspace_results = nil
  do_callbacks()
end

local function set_test_result_signs(bufnr, integration_name)
  local integ = integrations.get_by_name(integration_name)
  local tests = integ:find_tests(bufnr)
  if vim.tbl_isempty(tests) then
    return
  end
  vim.fn.sign_unplace(sign_group, { buffer = bufnr })
  sign_bufnrs[bufnr] = true
  for _, test in ipairs(tests) do
    local result = M.results[test.id]
    if result and result.status ~= TEST_STATUS.NONE then
      vim.fn.sign_place(0, sign_group, string.format("OverseerTest%s", result.status), bufnr, {
        priority = 8,
        lnum = test.lnum + 1,
      })
    end
  end
end

local test_results_version = setmetatable({}, {
  __index = function()
    return 0
  end,
})

M.update_buffer_signs = function(bufnr)
  for _, integ in ipairs(integrations.get_for_buf(bufnr)) do
    local varname = string.format("overseer_test_results_version_%s", integ.name)
    local ok, version = pcall(vim.api.nvim_buf_get_var, bufnr, varname)
    if ok and version == test_results_version[integ.name] then
      goto continue
    end

    set_test_result_signs(bufnr, integ.name)

    ::continue::
  end
end

local function normalize_test(integration_name, test)
  test.integration = integration_name
  if not test.path then
    test.path = {}
  end
  return test
end

local function diagnostic_from_test(integration_name, test)
  return {
    message = test.text,
    severity = test.type and vim.diagnostic.severity[test.type] or vim.diagnostic.severity.ERROR,
    lnum = (test.lnum or 1) - 1,
    end_lnum = test.end_lnum and (test.end_lnum - 1),
    col = test.col or 0,
    end_col = test.end_col,
    source = integration_name,
  }
end

local function update_all_signs()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    M.update_buffer_signs(bufnr)
  end
end

M.set_test_results = function(task, results)
  remove_diagnostics()
  if not results.tests then
    return
  end
  local integration_name = task.metadata.test_integration
  test_results_version[integration_name] = 1 + test_results_version[integration_name]
  -- Set test results
  if reset_on_next_results then
    M.results = {}
    reset_on_next_results = false
  end
  for _, v in ipairs(results.tests) do
    M.results[v.id] = normalize_test(integration_name, v)
  end
  cached_workspace_results = nil

  -- Set test result signs
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    M.update_buffer_signs(bufnr)
  end

  -- Set diagnostics
  local grouped = util.tbl_group_by(results.diagnostics, "filename")
  for filename, items in pairs(grouped) do
    local diagnostics = {}
    for _, item in ipairs(items) do
      table.insert(diagnostics, diagnostic_from_test(integration_name, item))
    end
    local bufnr = vim.fn.bufadd(filename)
    if bufnr then
      vim.diagnostic.set(test_ns, bufnr, diagnostics, {
        -- TODO configure these
        -- virtual_text = params.virtual_text,
        -- signs = params.signs,
        -- underline = params.underline,
      })
      table.insert(diagnostics_bufnrs, bufnr)
      if not vim.api.nvim_buf_is_loaded(bufnr) then
        util.set_bufenter_callback(bufnr, "diagnostics_show", function()
          vim.diagnostic.show(test_ns, bufnr)
        end)
      end
    else
      vim.notify(string.format("Could not find file '%s'", filename), vim.log.levels.WARN)
    end
  end

  do_callbacks()
end

M.add_test_result = function(task, key, result)
  local integration_name = task.metadata.test_integration
  if key == "tests" then
    M.results[result.id] = normalize_test(integration_name, result)
    add_workspace_result(result)

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local bufnr = vim.api.nvim_win_get_buf(win)
      set_test_result_signs(bufnr, integration_name)
    end

    do_callbacks()
  elseif key == "diagnostics" then
    local bufnr = vim.fn.bufadd(result.filename)
    if bufnr then
      local diagnostics = vim.diagnostic.get(bufnr, { namespace = test_ns }) or {}
      table.insert(diagnostics, diagnostic_from_test(integration_name, result))
      vim.diagnostic.set(test_ns, bufnr, diagnostics, {
        -- TODO configure these
        -- virtual_text = params.virtual_text,
        -- signs = params.signs,
        -- underline = params.underline,
      })
      if not vim.tbl_contains(diagnostics_bufnrs, bufnr) then
        table.insert(diagnostics_bufnrs, bufnr)
      end
    end
  end
end

M.reset_dir_results = function(dirname)
  -- TODO figure out which values to clear instead of clearing all of them
  reset_on_next_results = true
  for _, v in pairs(M.results) do
    v.status = TEST_STATUS.NONE
  end
  cached_workspace_results = nil
  update_all_signs()
end

M.reset_test_status = function(id, status)
  status = status or TEST_STATUS.NONE
  local result = M.results[id]
  if result then
    result.status = status
  end
  cached_workspace_results = nil
  update_all_signs()
end

local function path_match(group, test)
  if not test.path then
    return false
  end
  for i, v in ipairs(group) do
    if v ~= test.path[i] then
      return false
    end
  end
  return true
end

M.reset_group_status = function(path, status)
  status = status or TEST_STATUS.NONE
  for _, v in pairs(M.results) do
    if path_match(path, v) then
      v.status = status
    end
  end
  cached_workspace_results = nil
  update_all_signs()
end

M.touch = do_callbacks

return M
