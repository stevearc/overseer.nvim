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
    line_to_task = {},
  }, {__index = TaskList})

  vim.api.nvim_create_autocmd({'BufHidden', 'WinLeave'}, {
    desc = "Close preview window when task list closes",
    buffer = bufnr,
    command = 'pclose',
  })
  vim.api.nvim_create_autocmd('BufUnload', {
    desc = "Clean up references on buffer unload",
    buffer = bufnr,
    callback = function()
      ref = nil
    end,
    once = true,
  })
  vim.api.nvim_create_autocmd('CursorMoved', {
    desc = "Update preview window when cursor moves",
    buffer = bufnr,
    callback = function()
      tl:update_preview()
    end,
  })

  vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', '', {
    callback = function()
      tl:prompt_action()
    end,
  })

  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'o', '', {
    callback = function()
      tl:open_buffer()
    end,
  })

  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'p', '', {
    callback = function()
      tl:show_preview()
    end,
  })

  ref = tl
  return tl
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

function TaskList:prompt_action()
  local task = self:_get_task_from_line()
  if not task then
    return
  end

  local actions = {}
  if task.status == STATUS.PENDING then
    table.insert(actions, 'start')
  elseif task.status == STATUS.RUNNING then
    table.insert(actions, 'stop')
  else
    table.insert(actions, 'rerun')
    table.insert(actions, 'dispose')
    table.insert(actions, 'rerun on change')
  end

  vim.ui.select(actions, {
    prompt = 'Task actions',
    kind = 'overseer_task_options',
  }, function(action)
    if action then
      if action == 'rerun on change' then
        vim.notify("TODO FIXME implement")
      else
        task[action](task)
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
      for k,v in pairs(task.result) do
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

return M
