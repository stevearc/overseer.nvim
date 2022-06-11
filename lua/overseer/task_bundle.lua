local confirm = require("overseer.confirm")
local files = require("overseer.files")
local log = require("overseer.log")
local Task = require("overseer.task")
local task_list = require("overseer.task_list")
local M = {}

local function get_bundle_dir()
  return files.get_stdpath_filename("state", "overseer")
end

local function get_bundle_previewer()
  local ok, Previewer = pcall(require, "telescope.previewers.previewer")
  if not ok then
    return nil
  end

  return Previewer:new({
    title = "Task bundle",
    setup = function(self)
      return {
        bufnr = vim.api.nvim_create_buf(false, true),
      }
    end,
    teardown = function(self)
      vim.api.nvim_buf_delete(self.state.bufnr, { force = true })
    end,
    preview_fn = function(self, entry, status)
      local ns = vim.api.nvim_create_namespace("overseer")
      vim.api.nvim_buf_clear_namespace(self.state.bufnr, ns, 0, -1)
      vim.api.nvim_win_set_buf(status.preview_win, self.state.bufnr)
      local lines = {}
      local highlights = {}
      local data = files.load_json_file(
        files.join(get_bundle_dir(), string.format("%s.bundle.json", entry.value))
      )
      for _, params in ipairs(data) do
        local task_ok, task = pcall(Task.new_uninitialized, params)
        if task_ok then
          task:render(lines, highlights, 3)
        end
      end
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, true, lines)
      for _, hl in ipairs(highlights) do
        local group, row, col_start, col_end = unpack(hl)
        vim.api.nvim_buf_add_highlight(self.state.bufnr, ns, group, row - 1, col_start, col_end)
      end
    end,
  })
end

M.list_task_bundles = function()
  local bundle_dir = get_bundle_dir()
  local fd = vim.loop.fs_opendir(bundle_dir, nil, 32)
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
    local filepath = files.join(get_bundle_dir(), string.format("%s.bundle.json", name))
    local data = files.load_json_file(filepath)
    local count = 0
    for _, params in ipairs(data) do
      local ok, task = pcall(Task.new, params)
      if ok then
        count = count + 1
        task:start()
      else
        log:error("Could not load task in bundle %s: %s", filepath, task)
      end
    end
    vim.notify(string.format("Started %d tasks", count))
  else
    local tasks = M.list_task_bundles()
    if #tasks == 0 then
      vim.notify("No saved task bundles", vim.log.levels.WARN)
      return
    end
    vim.ui.select(tasks, {
      prompt = "Load task bundle:",
      kind = "overseer_task_bundle",
      telescope = {
        previewer = get_bundle_previewer(),
      },
    }, function(selected)
      if selected then
        M.load_task_bundle(selected)
      end
    end)
  end
end

M.save_task_bundle = function(name, tasks)
  if name then
    local filename = string.format("%s.bundle.json", name)
    local serialized
    if tasks then
      serialized = {}
      for _, task in ipairs(tasks) do
        if task:is_serializable() then
          table.insert(serialized, task:serialize())
        end
      end
    else
      serialized = task_list.serialize_tasks()
    end
    local filepath = files.join(get_bundle_dir(), filename)
    if files.exists(filepath) then
      confirm({
        message = string.format(
          "%s exists.\nWould you like to overwrite it or append to it?",
          filename
        ),
        choices = {
          "&Overwrite",
          "&Append",
          "Cancel",
        },
        default = 3,
      }, function(idx)
        if idx == 1 then
          files.write_json_file(filepath, serialized)
        elseif idx == 2 then
          local data = files.load_json_file(files.join(get_bundle_dir(), filename))
          for _, new_task in ipairs(serialized) do
            table.insert(data, new_task)
          end
          files.write_json_file(filepath, data)
        end
      end)
    else
      files.write_json_file(filepath, serialized)
    end
  else
    vim.ui.input({
      prompt = "Task bundle name:",
      completion = "customlist,overseer#task_bundle_completelist",
    }, function(selected)
      if selected then
        M.save_task_bundle(selected, tasks)
      end
    end)
  end
end

M.delete_task_bundle = function(name)
  if name then
    local filename = string.format("%s.bundle.json", name)
    if not files.delete_file(files.join(get_bundle_dir(), filename)) then
      vim.notify(string.format("No task bundle at %s", filename))
    end
  else
    local tasks = M.list_task_bundles()
    if #tasks == 0 then
      vim.notify("No saved task bundles", vim.log.levels.WARN)
      return
    end
    vim.ui.select(tasks, {
      prompt = "Delete task bundle:",
      kind = "overseer_task_bundle",
      telescope = {
        previewer = get_bundle_previewer(),
      },
    }, function(selected)
      if selected then
        M.delete_task_bundle(selected)
      end
    end)
  end
end

return M
