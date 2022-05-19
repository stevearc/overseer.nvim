local config = require("overseer.config")
local registry = require("overseer.registry")
local Task = require("overseer.task")
local template = require("overseer.template")
local util = require("overseer.util")
local window = require("overseer.window")
local M = {}

-- TODO
-- * { } to navigate task list
-- * Colorize task list
-- * Maybe need category/tags for templates? (e.g. "Run test")
-- * Rerun on save optionally takes directory
-- * Autostart task on vim open in dir (needs some uniqueness checks)
--
-- WISHLIST
-- * re-run can interrupt (stop job)
-- * Definitely going to need some sort of logging system
-- * Live build a task from a template + components
-- * Load VSCode task definitions
-- * Store recent commands in history per-directory
--   * Can select & run task from recent history
-- * Add tests
-- * Maybe add a way to customize the task detail per-piece. e.g. {components = 0, result = 2}
-- * add debugging helpers for components
-- * component: parse output and populate quickfix
-- * task list: bulk actions
-- * ability to require task to be unique (disallow duplicates). Coordinate among all vim instances
-- * Quick jump to most recent task (started/notified)
-- * Rerun trigger handler feels different from the rest. Maybe separate it out.
-- * Lualine component
-- * Separation of registry and task list feels like it needs refactor

M.setup = function(opts)
  require("overseer.component").register_all()
  config.setup(opts)
  vim.api.nvim_create_user_command('OverseerSaveBundle', function(params)
    M.save_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Serialize the current tasks to disk",
    nargs = '?',
  })
  vim.api.nvim_create_user_command('OverseerLoadBundle', function(params)
    M.load_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Load tasks that were serialized to disk",
    nargs = '?',
  })
  vim.api.nvim_create_user_command('OverseerDeleteBundle', function(params)
    M.delete_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Delete a saved task bundle",
    nargs = '?',
  })
end

M.new_task = function(opts)
  return Task.new(opts)
end

M.toggle = window.toggle
M.open = window.open
M.close = window.close

M.load_from_template = function(name, params, silent)
  vim.validate({
    name = { name, "s" },
    params = { params, "t", true },
    silent = { silent, "b", true },
  })
  params = params or {}
  params.bufname = vim.api.nvim_buf_get_name(0)
  params.dirname = vim.fn.getcwd(0)
  local dir = params.bufname
  if dir == "" then
    dir = params.dirname
  end
  local ft = vim.api.nvim_buf_get_option(0, "filetype")
  local tmpl = template.get_by_name(name, dir, ft)
  if not tmpl then
    if silent then
      return
    else
      error(string.format("Could not find template '%s'", name))
    end
  end
  return tmpl:build(params)
end

M.list_task_bundles = function()
  local cache_dir = util.get_cache_dir()
  local fd = vim.loop.fs_opendir(cache_dir, nil, 32)
  local entries = vim.loop.fs_readdir(fd)
  local ret = {}
  while entries do
    for _,entry in ipairs(entries) do
      if entry.type == 'file' then
        local name = entry.name:match("^(.+)%.bundle%.json$")
        if name then
          table.insert(ret, name)
        end
      end
    end
    entries = vim.loop.fs_readdir(fd)
  end
  vim.loop.fs_closedir(fd)
  return ret
end

M.load_task_bundle = function(name)
  if name then
    local cache_dir = util.get_cache_dir()
    local filename = util.join(cache_dir, string.format("%s.bundle.json", name))
    if not util.path_exists(filename) then
      vim.notify(string.format("No task bundle found at %s", filename), vim.log.levels.ERROR)
      return
    end
    local fd = vim.loop.fs_open(filename, 'r', 420) -- 0644
    local stat = vim.loop.fs_fstat(fd)
    local content = vim.loop.fs_read(fd, stat.size)
    vim.loop.fs_close(fd)
    local data = vim.json.decode(content)
    for _,params in ipairs(data) do
      local task = M.new_task(params)
      task:start()
    end
    vim.notify(string.format("Started %d tasks", #data))
  else
    local tasks = M.list_task_bundles()
    if #tasks == 0 then
      vim.notify("No saved task bundles", vim.log.levels.WARN)
      return
    end
    vim.ui.select(tasks, {
      prompt = "Task bundle:",
      kind = "overseer_task_bundle",
    }, function(name)
      if name then
        M.load_task_bundle(name)
      end
    end)
  end
end

M.save_task_bundle = function(name)
  if name then
    local cache_dir = util.get_cache_dir()
    if not util.path_exists(cache_dir) then
      vim.loop.fs_mkdir(cache_dir, 493) -- 0755
    end
    local filename = util.join(cache_dir, string.format("%s.bundle.json", name))
    local fd = vim.loop.fs_open(filename, 'w', 420) -- 0644
    vim.loop.fs_write(fd, vim.json.encode(registry.serialize_tasks()))
    vim.loop.fs_close(fd)
  else
    vim.ui.input({
      prompt = "Task bundle name:",
    }, function(name)
      if name then
        M.save_task_bundle(name)
      end
    end)
  end
end

M.delete_task_bundle = function(name)
  if name then
    local cache_dir = util.get_cache_dir()
    local filename = util.join(cache_dir, string.format("%s.bundle.json", name))
    if util.path_exists(filename) then
      vim.loop.fs_unlink(filename)
    else
      vim.notify(string.format("No task bundle at %s", filename))
    end
  else
    local tasks = M.list_task_bundles()
    if #tasks == 0 then
      vim.notify("No saved task bundles", vim.log.levels.WARN)
      return
    end
    vim.ui.select(tasks, {
      prompt = "Task bundle:",
      kind = "overseer_task_bundle",
    }, function(name)
      if name then
        M.delete_task_bundle(name)
      end
    end)
  end
end

M.start_from_template = function(name, params)
  vim.validate({
    name = { name, "s", true },
    params = { params, "t", true },
  })
  if name then
    local task = M.load_from_template(name, params)
    task:start()
    return
  end
  params = params or {}
  params.bufname = vim.api.nvim_buf_get_name(0)
  params.dirname = vim.fn.getcwd(0)
  local dir = params.bufname
  if dir == "" then
    dir = params.dirname
  end
  local ft = vim.api.nvim_buf_get_option(0, "filetype")

  local templates = template.list(dir, ft)
  vim.ui.select(templates, {
    prompt = "Task template:",
    kind = "overseer_template",
    format_item = function(tmpl)
      if tmpl.description then
        return string.format("%s (%s)", tmpl.name, tmpl.description)
      else
        return tmpl.name
      end
    end,
  }, function(tmpl)
    if tmpl then
      tmpl:prompt(params, function(task)
        if task then
          task:start()
        end
      end)
    end
  end)
end

setmetatable(M, {
  __index = function(_, key)
    local ok, val = pcall(require, string.format("overseer.%s", key))
    if ok then
      return val
    else
      error(string.format("Error requiring overseer.%s: %s", key, val))
    end
  end,
})

return M
