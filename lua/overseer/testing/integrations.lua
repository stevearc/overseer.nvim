local config = require("overseer.config")
local files = require("overseer.files")
local parsers = require("overseer.parsers")
local Task = require("overseer.task")
local M = {}

local registry = {}

local builtin_tests = { "go.go_test", "lua.plenary_busted", "python.unittest" }

local function register_builtin()
  local seen = {}
  if config.testing.modify then
    for _, integration in ipairs(config.testing.modify) do
      if not seen[integration.name] then
        seen[integration.name] = true
        table.insert(registry, integration)
        if integration.parser then
          parsers.register_parser(integration.name, integration.parser)
        end
      end
    end
  end
  if config.testing.disable ~= true then
    for _, mod in ipairs(builtin_tests) do
      if not config.testing.disable or not vim.tbl_contains(config.testing.disable, mod) then
        local integration = require(string.format("overseer.testing.%s", mod))
        if not seen[integration.name] then
          seen[integration.name] = true
          table.insert(registry, integration)
          if integration.parser then
            parsers.register_parser(integration.name, integration.parser)
          end
        end
      end
    end
  end
end

local initialized = false
local function initialize()
  if initialized then
    return
  end
  initialized = true
  if not config.testing.disable_builtin then
    register_builtin()
  end
end

local function get_dir_integrations(filename)
  local ret = {}
  local seen = {}
  -- Iterate through dirs in reverse length order so we prioritize the *most*
  -- specific directory
  local dirs = vim.tbl_keys(config.testing.dirs)
  table.sort(dirs, function(a, b)
    return b < a
  end)

  -- Add the directory-specific integrations
  for _, dir in ipairs(dirs) do
    if files.is_subpath(dir, filename) then
      local dir_integrations = config.testing.dirs[dir]
      for _, integration in ipairs(dir_integrations) do
        if not seen[integration.name] then
          seen[integration.name] = true
          table.insert(ret, integration)
        end
      end
    end
  end
  return ret, seen
end

M.get_for_dir = function(dirname)
  initialize()
  local ret, seen = get_dir_integrations(dirname)

  -- Add all registered integrations
  for _, integration in ipairs(registry) do
    if not seen[integration.name] then
      seen[integration.name] = true
      if integration:is_workspace_match(dirname) then
        table.insert(ret, integration)
      end
    end
  end
  return ret
end

M.get_for_buf = function(bufnr)
  initialize()
  bufnr = bufnr or 0
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local ret, seen = get_dir_integrations(filename)
  for _, integration in ipairs(registry) do
    if not seen[integration.name] then
      seen[integration.name] = true
      local tests = integration:find_tests(bufnr)
      if not vim.tbl_isempty(tests) then
        table.insert(ret, integration)
      end
    end
  end
  return ret
end

M.get_by_name = function(name)
  initialize()
  local ret = M.get_for_dir(vim.fn.getcwd(0))
  for _, integration in ipairs(ret) do
    if integration.name == name then
      return integration
    end
  end
end

M.create_and_start_task = function(integ, task_data)
  -- TODO adjust data through user config
  if not task_data.components then
    task_data.components = { "default_test" }
    if integ.parser then
      table.insert(task_data.components, 1, { "result_exit_code", parser = integ.name })
    end
  end
  task_data.metadata = task_data.metadata or {}
  task_data.metadata.test_integration = integ.name
  local task = Task.new(task_data)
  task:start()
  return task
end

return M
