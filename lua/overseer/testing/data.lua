local Enum = require("overseer.enum")
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

local cached_workspace_results
M.get_workspace_results = function()
  if cached_workspace_results then
    return cached_workspace_results
  end
  local results = vim.tbl_values(M.results)
  table.sort(results, function(a, b)
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
  end)

  local root = new_summary()
  local summaries = { ["_"] = root }
  for _, v in ipairs(results) do
    root[v.status] = 1 + root[v.status]
    local cur = summaries
    for _, path in ipairs(v.path) do
      if not cur[path] then
        cur[path] = new_summary()
      end
      cur = cur[path]
      cur[v.status] = 1 + cur[v.status]
    end
  end

  cached_workspace_results = {
    tests = results,
    summaries = summaries,
  }
  return cached_workspace_results
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
M.set_test_results = function(results)
  if not results.tests then
    return
  end
  if reset_on_next_results then
    M.results = {}
    reset_on_next_results = false
  end
  for _, v in ipairs(results.tests) do
    M.results[v.id] = v
  end
  cached_workspace_results = nil
  do_callbacks()
end

M.reset_dir_results = function(dirname)
  -- TODO figure out which values to clear instead of clearing all of them
  reset_on_next_results = true
  for _, v in pairs(M.results) do
    v.status = TEST_STATUS.NONE
  end
  cached_workspace_results = nil
end

M.reset_test_status = function(id)
  local result = M.results[id]
  if result then
    result.status = TEST_STATUS.NONE
  end
  cached_workspace_results = nil
end

M.touch = do_callbacks

return M
