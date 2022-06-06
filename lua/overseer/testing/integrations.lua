local config = require("overseer.config")
local files = require("overseer.files")
local parsers = require("overseer.parsers")
local Task = require("overseer.task")
local M = {}

local registry = {}

local builtin_tests = {
  "go.go_test",
  "javascript.jest",
  "lua.busted",
  "lua.plenary_busted",
  "python.unittest",
  "ruby.rspec",
}

local num_tasks_running = 0
local next_id = 1

local function assign_id(integration)
  -- Using rawget so that we don't hit the __index metamethod of wrapped tests
  if not rawget(integration, "id") then
    rawset(integration, "id", next_id)
    registry[next_id] = integration
    next_id = next_id + 1
    if integration.parser then
      parsers.register_parser(integration.id, integration.parser)
    end
  end
  return integration
end

local function register_builtin()
  local seen = {}
  if config.testing.modify then
    for _, integration in ipairs(config.testing.modify) do
      if not seen[integration.name] then
        seen[integration.name] = true
        assign_id(integration)
      end
    end
  end
  if config.testing.disable ~= true then
    for _, mod in ipairs(builtin_tests) do
      if not config.testing.disable or not vim.tbl_contains(config.testing.disable, mod) then
        local integration = require(string.format("overseer.testing.%s", mod))
        if not seen[integration.name] then
          seen[integration.name] = true
          assign_id(integration)
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
          table.insert(ret, assign_id(integration))
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
  for _, integration in pairs(registry) do
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
  for _, integration in pairs(registry) do
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

M.get = function(id)
  initialize()
  return registry[id]
end

local last_task = nil

local pending_tasks = {}
M.create_and_start_task = function(integ, task_data, reset_params)
  if num_tasks_running >= config.testing.max_concurrent_tests then
    table.insert(pending_tasks, { integ, task_data, reset_params })
    return
  end

  if last_task then
    last_task:dec_reference()
    if not last_task:is_running() then
      last_task:dispose()
    end
  end
  if not task_data.components then
    task_data.components = { "default_test" }
    if integ.parser then
      table.insert(task_data.components, 1, { "result_exit_code", parser = integ.id })
    end
  end
  -- Add the test reset component
  if reset_params and not vim.tbl_isempty(reset_params) then
    reset_params[1] = "on_start_reset_tests"
    table.insert(task_data.components, 1, reset_params)
  end

  task_data.metadata = task_data.metadata or {}
  task_data.metadata.test_integration_id = integ.id
  local task = Task.new(task_data)
  task:inc_reference()
  last_task = task
  task:start()
end

M.rerun_last_task = function()
  if last_task then
    last_task:rerun()
    return true
  end
end

M.record_start = function(task)
  num_tasks_running = num_tasks_running + 1
end

M.record_finish = function(task)
  num_tasks_running = num_tasks_running - 1
  if
    num_tasks_running < config.testing.max_concurrent_tests and not vim.tbl_isempty(pending_tasks)
  then
    local args = table.remove(pending_tasks)
    M.create_and_start_task(unpack(args))
  end
end

return M
