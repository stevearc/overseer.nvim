local Enum = require("overseer.enum")
local M = {}

M.TEST_STATUS = Enum.new({ "NONE", "RUNNING", "SUCCESS", "FAILURE", "SKIPPED" })

local callbacks = {}

M.results = {}

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
  cached_workspace_results = results
  return results
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

M.set_test_results = function(results)
  if not results.tests then
    return
  end
  cached_workspace_results = nil
  for _, v in ipairs(results.tests) do
    M.results[v.id] = v
  end
  for _, cb in ipairs(callbacks) do
    cb()
  end
end

M.clear_results = function(path)
  --
end

M.reset_results = function()
  --
end

return M
