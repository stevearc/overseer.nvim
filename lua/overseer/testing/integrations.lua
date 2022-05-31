local M = {}

M.registry = {}

local builtin_tests = { "python.unittest" }
M.register_builtin = function()
  for _, mod in ipairs(builtin_tests) do
    table.insert(M.registry, require(string.format("overseer.testing.%s", mod)))
  end
end

M.get_for_dir = function(dirname)
  local ret = {}
  for _, integration in ipairs(M.registry) do
    if integration:is_workspace_match(dirname) then
      table.insert(ret, integration)
    end
  end
  return ret
end

M.get_for_buf = function(bufnr)
  bufnr = bufnr or 0
  local ret = {}
  for _, integration in ipairs(M.registry) do
    local tests = integration:find_tests(bufnr)
    if not vim.tbl_isempty(tests) then
      table.insert(ret, integration)
    end
  end
  return ret
end

M.get_by_name = function(name)
  for _, integration in ipairs(M.registry) do
    if integration.name == name then
      return integration
    end
  end
end

return M
