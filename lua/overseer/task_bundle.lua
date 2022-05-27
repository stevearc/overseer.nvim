local files = require("overseer.files")
local Task = require("overseer.task")
local task_list = require("overseer.task_list")
local M = {}

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
      local data = files.load_data_file(string.format("%s.bundle.json", entry.value))
      for _, params in ipairs(data) do
        local task = Task.new_uninitialized(params)
        task:render(lines, highlights, 3)
      end
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, true, lines)
      for _, hl in ipairs(highlights) do
        local group, row, col_start, col_end = unpack(hl)
        vim.api.nvim_buf_add_highlight(self.state.bufnr, ns, group, row - 1, col_start, col_end)
      end
    end,
  })
end

_G.overseer_task_bundle_completion = function()
  return M.list_task_bundles()
end

M.list_task_bundles = function()
  local data_dir = files.get_data_dir()
  local fd = vim.loop.fs_opendir(data_dir, nil, 32)
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
    local data = files.load_data_file(string.format("%s.bundle.json", name))
    for _, params in ipairs(data) do
      local task = Task.new(params)
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

M.save_task_bundle = function(name)
  if name then
    files.write_data_file(string.format("%s.bundle.json", name), task_list.serialize_tasks())
  else
    vim.ui.input({
      prompt = "Task bundle name:",
      completion = "customlist,overseer#task_bundle_completelist",
    }, function(selected)
      if selected then
        M.save_task_bundle(selected)
      end
    end)
  end
end

M.delete_task_bundle = function(name)
  if name then
    local filename = string.format("%s.bundle.json", name)
    if not files.delete_data_file(filename) then
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
