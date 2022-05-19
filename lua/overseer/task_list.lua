local constants = require("overseer.constants")
local util = require("overseer.util")
local STATUS = constants.STATUS
local M = {}

local TaskList = {}

local ref

M.get_or_create = function()
  if not ref then
    ref = TaskList.new()
  end
  return ref
end

function TaskList.new()
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local tl = setmetatable({
    bufnr = bufnr,
    actions = {
      {
        name = "start",
        condition = function(task)
          return task.status == STATUS.PENDING
        end,
        callback = function(task)
          task:start()
        end,
      },
      {
        name = "stop",
        condition = function(task)
          return task.status == STATUS.RUNNING
        end,
        callback = function(task)
          task:stop()
        end,
      },
      {
        name = "rerun",
        condition = function(task)
          return task.status ~= STATUS.PENDING and task.status ~= STATUS.RUNNING
        end,
        callback = function(task)
          task:rerun()
        end,
      },
      {
        name = "dispose",
        condition = function(task)
          return task.status ~= STATUS.PENDING and task.status ~= STATUS.RUNNING
        end,
        callback = function(task)
          task:dispose()
        end,
      },
      {
        name = "rerun on save",
        condition = function(task)
          return not task:has_capability("rerun_on_save")
        end,
        callback = function(task)
          task:add_capability("rerun_on_save")
        end,
      },
    },
    line_to_task = {},
  }, { __index = TaskList })

  vim.api.nvim_create_autocmd({ "BufHidden", "WinLeave" }, {
    desc = "Close preview window when task list closes",
    buffer = bufnr,
    command = "pclose",
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    desc = "Clean up references on buffer unload",
    buffer = bufnr,
    callback = function()
      ref = nil
    end,
    once = true,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    desc = "Update preview window when cursor moves",
    buffer = bufnr,
    callback = function()
      tl:update_preview()
    end,
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
    callback = function()
      tl:run_action()
    end,
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "o", "", {
    callback = function()
      tl:open_buffer()
    end,
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "p", "", {
    callback = function()
      tl:show_preview()
    end,
  })

  ref = tl
  return tl
end

function TaskList:register_action(opts)
  vim.validate({
    name = { opts.name, "s" },
    condition = { opts.condition, "f" },
    callback = { opts.callback, "f" },
  })
  table.insert(self.actions, opts)
end

function TaskList:_get_task_from_line(lnum)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  return self.line_to_task[lnum]
end

function TaskList:show_preview()
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
    return
  end

  local bufname = vim.api.nvim_buf_get_name(task.bufnr)
  vim.cmd(string.format("vertical pedit %s", bufname))
  local winid = util.get_preview_window()
  if winid then
    util.scroll_to_end(winid)
  end
end

function TaskList:update_preview()
  local winid = util.get_preview_window()
  if not winid then
    return
  end
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
    return
  end

  local task_buf_name = vim.api.nvim_buf_get_name(task.bufnr)
  local winbuf = vim.api.nvim_win_get_buf(winid)
  local preview_buf_name = vim.api.nvim_buf_get_name(winbuf)
  if task_buf_name ~= win_buf_name then
    self:show_preview()
  end
end

function TaskList:open_buffer()
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
    return
  end

  vim.cmd([[normal! m']])
  vim.api.nvim_win_set_buf(0, task.bufnr)
  util.scroll_to_end(0)
end

function TaskList:run_action(name)
  vim.validate({ name = { name, "s", true } })
  local task = self:_get_task_from_line()
  if not task then
    return
  end

  print("Run action")
  local actions = {}
  for _, action in ipairs(self.actions) do
    print(string.format("action: %s", vim.inspect(action)))
    if action.condition(task, self) then
      if action.name == name then
        action.callback(task, self)
        return
      end
      table.insert(actions, action)
    end
  end
  if name then
    vim.notify(string.format("No action '%s' found for task", name), vim.log.levels.ERROR)
    return
  end

  print(string.format("actions %s", vim.inspect(actions)))
  vim.ui.select(actions, {
    prompt = "Task actions",
    kind = "overseer_task_options",
    format_item = function(action)
      return action.name
    end,
  }, function(action)
    if action then
      if action.condition(task, self) then
        action.callback(task, self)
      else
        vim.notify(
          string.format("Can no longer perform action '%s' on task", action.name),
          vim.log.levels.WARN
        )
      end
    end
  end)
end

function TaskList:render(tasks)
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return false
  end

  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  local lines = {}
  self.line_to_task = {}
  for _, task in ipairs(tasks) do
    table.insert(lines, task.name)
    table.insert(self.line_to_task, task)
    table.insert(lines, task.status .. ": " .. task.summary)
    table.insert(self.line_to_task, task)

    if task.result and not vim.tbl_isempty(task.result) then
      for k, v in pairs(task.result) do
        table.insert(lines, string.format("  %s: %s", k, v))
        table.insert(self.line_to_task, task)
      end
    end
    table.insert(lines, "----------")
    table.insert(self.line_to_task, nil)
  end
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)

  return true
end

M.new = TaskList.new

M.register_action = function(...)
  local tl = M.get_or_create()
  tl:register_action(...)
end

return M
