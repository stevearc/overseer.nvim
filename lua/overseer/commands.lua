local M = {}
local registry = require("overseer.registry")
local util = require("overseer.util")
local template = require("overseer.template")
local window = require("overseer.window")

M.create_commands = function()
  vim.api.nvim_create_user_command("OverseerOpen", function()
    window.open()
  end, {
    desc = "Open the overseer window",
  })
  vim.api.nvim_create_user_command("OverseerClose", function()
    window.close()
  end, {
    desc = "Close the overseer window",
  })
  vim.api.nvim_create_user_command("OverseerToggle", function()
    window.toggle()
  end, {
    desc = "Toggle the overseer window",
  })
  vim.api.nvim_create_user_command("OverseerSaveBundle", function(params)
    M.save_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Serialize the current tasks to disk",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerLoadBundle", function(params)
    M.load_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Load tasks that were serialized to disk",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerDeleteBundle", function(params)
    M.delete_task_bundle(params.args ~= "" and params.args or nil)
  end, {
    desc = "Delete a saved task bundle",
    nargs = "?",
  })
  vim.api.nvim_create_user_command("OverseerRun", function(params)
    local opts = {
      name = params.args ~= "" and params.args or nil,
    }
    M.run_template(opts)
  end, {
    desc = "Run a task from a template",
    nargs = "?",
  })
end

-- TEMPLATE LOADING/RUNNING

M.run_template = function(opts, params, callback)
  opts = opts or {}
  vim.validate({
    name = { opts.name, "s", true },
    tags = { opts.tags, "t", true },
    nostart = { opts.nostart, "b", true },
    callback = { callback, "f", true },
  })
  params = params or {}
  params.bufname = vim.api.nvim_buf_get_name(0)
  params.dirname = vim.fn.getcwd(0)
  local dir = params.bufname
  if dir == "" then
    dir = params.dirname
  end
  local ft = vim.api.nvim_buf_get_option(0, "filetype")
  if opts.name then
    local tmpl = template.get_by_name(opts.name, { dir = dir, filetype = ft, tags = opts.tags })
    if not tmpl then
      error(string.format("Could not find template '%s'", opts.name))
    end
    tmpl:prompt(params, function(task)
      if not opts.nostart then
        task:start()
      end
      if callback then
        callback(task)
      end
    end)
  else
    local templates = template.list({ dir = dir, filetype = ft, tags = opts.tags })
    if #templates == 0 then
      vim.notify("Could not find any matching task templates", vim.log.levels.ERROR)
      return
    elseif #templates == 1 then
      opts.name = templates[1].name
      M.run_template(opts, params, callback)
    else
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
          opts.name = tmpl.name
          M.run_template(opts, params, callback)
        end
      end)
    end
  end
end

-- TASK BUNDLE

M.list_task_bundles = function()
  local cache_dir = util.get_cache_dir()
  local fd = vim.loop.fs_opendir(cache_dir, nil, 32)
  local entries = vim.loop.fs_readdir(fd)
  local ret = {}
  while entries do
    for _, entry in ipairs(entries) do
      if entry.type == "file" then
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
    local fd = vim.loop.fs_open(filename, "r", 420) -- 0644
    local stat = vim.loop.fs_fstat(fd)
    local content = vim.loop.fs_read(fd, stat.size)
    vim.loop.fs_close(fd)
    local data = vim.json.decode(content)
    for _, params in ipairs(data) do
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
    }, function(selected)
      if selected then
        M.load_task_bundle(selected)
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
    local fd = vim.loop.fs_open(filename, "w", 420) -- 0644
    vim.loop.fs_write(fd, vim.json.encode(registry.serialize_tasks()))
    vim.loop.fs_close(fd)
  else
    vim.ui.input({
      prompt = "Task bundle name:",
    }, function(selected)
      if selected then
        M.save_task_bundle(selected)
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
    }, function(selected)
      if selected then
        M.delete_task_bundle(selected)
      end
    end)
  end
end

return M
