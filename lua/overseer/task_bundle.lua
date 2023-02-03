local config = require("overseer.config")
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

---@return string[]
M.list_task_bundles = function()
  local bundle_dir = get_bundle_dir()
  if not files.exists(bundle_dir) then
    return {}
  end
  local filenames = files.list_files(bundle_dir)
  local ret = {}
  for _, filename in ipairs(filenames) do
    local name = filename:match("^(.+)%.bundle%.json$")
    if name then
      table.insert(ret, name)
    end
  end
  return ret
end

---@param name nil|string
---@param opts nil|table
---    ignore_missing nil|boolean When true, don't notify if bundle doesn't exist
---    autostart nil|boolean When true, start the tasks after loading (default true)
M.load_task_bundle = function(name, opts)
  vim.validate({
    name = { name, "s", true },
    opts = { opts, "t", true },
  })
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    autostart = true,
  })
  if name then
    local filepath = files.join(get_bundle_dir(), string.format("%s.bundle.json", name))
    local data = files.load_json_file(filepath)
    if not data then
      if not opts.ignore_missing then
        vim.notify(string.format("Could not find task bundle %s", name), vim.log.levels.ERROR)
      end
      return
    end
    local count = 0
    for _, params in ipairs(data) do
      local ok, task = pcall(Task.new, params)
      if ok then
        count = count + 1
        if opts.autostart then
          task:start()
        end
      else
        log:error("Could not load task in bundle %s: %s", filepath, task)
      end
    end
    vim.notify(string.format("Started %d tasks", count))
  else
    local tasks = M.list_task_bundles()
    if #tasks == 0 then
      if not opts.ignore_missing then
        vim.notify("No saved task bundles", vim.log.levels.WARN)
      end
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
        M.load_task_bundle(selected, opts)
      end
    end)
  end
end

---@param name? string
---@param tasks? overseer.Task[]
---@param opts? {on_conflict?: "overwrite"|"append"|"cancel"}
M.save_task_bundle = function(name, tasks, opts)
  vim.validate({
    name = { name, "s", true },
    tasks = { tasks, "t", true },
    opts = { opts, "t", true },
  })
  opts = opts or {}
  if name then
    local filename = string.format("%s.bundle.json", name)
    local serialized
    if tasks then
      serialized = {}
      for _, task in ipairs(tasks) do
        table.insert(serialized, task:serialize())
      end
    else
      serialized = vim.tbl_map(function(task)
        return task:serialize()
      end, task_list.list_tasks(config.bundles.save_task_opts))
    end
    if vim.tbl_isempty(serialized) then
      return
    end
    local filepath = files.join(get_bundle_dir(), filename)

    local function append_to_file()
      local data = files.load_json_file(files.join(get_bundle_dir(), filename))
      for _, new_task in ipairs(serialized) do
        table.insert(data, new_task)
      end
      files.write_json_file(filepath, data)
    end

    if files.exists(filepath) then
      if opts.on_conflict == "overwrite" then
        files.write_json_file(filepath, serialized)
      elseif opts.on_conflict == "append" then
        append_to_file()
      elseif opts.on_conflict == "cancel" then
        -- Do nothing
      else
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
            append_to_file()
          end
        end)
      end
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

---@param name? string
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
