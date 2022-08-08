local action_util = require("overseer.action_util")
local bindings = require("overseer.task_list.bindings")
local binding_util = require("overseer.binding_util")
local config = require("overseer.config")
local task_list = require("overseer.task_list")
local util = require("overseer.util")

local M = {}

local Sidebar = {}

local ref

M.get_or_create = function()
  local created = not ref
  if not ref then
    ref = Sidebar.new()
    vim.api.nvim_create_autocmd("BufUnload", {
      desc = "Clean up overseer sidebar reference on buffer unload",
      buffer = ref.bufnr,
      callback = function()
        ref = nil
      end,
      once = true,
    })
  end
  return ref, created
end

M.get = function()
  return ref
end

local MIN_DETAIL = 1
local MAX_DETAIL = 3

function Sidebar.new()
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local tl = setmetatable({
    bufnr = bufnr,
    default_detail = config.task_list.default_detail,
    task_detail = {},
    task_lines = {},
  }, { __index = Sidebar })

  vim.api.nvim_create_autocmd({ "BufHidden", "WinLeave" }, {
    desc = "Close preview window when task list closes",
    buffer = bufnr,
    command = "pclose",
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    desc = "Update preview window when cursor moves",
    buffer = bufnr,
    callback = function()
      tl:update_preview()
    end,
  })

  binding_util.create_plug_bindings(bufnr, bindings, tl)
  binding_util.create_bindings_to_plug(bufnr, "n", config.task_list.bindings, "OverseerTask:")

  return tl
end

function Sidebar:_get_task_from_line(lnum)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  for _, v in ipairs(self.task_lines) do
    if v[1] >= lnum then
      return v[2]
    end
  end
end

function Sidebar:toggle_preview()
  local pwin = util.get_preview_window()
  if pwin then
    vim.cmd([[pclose]])
    return
  end
  local task = self:_get_task_from_line()
  if not task or not task:get_bufnr() or not vim.api.nvim_buf_is_valid(task:get_bufnr()) then
    return
  end

  local win_width = vim.api.nvim_win_get_width(0)
  local padding = 1
  local width = vim.o.columns - win_width - 2 - 2 * padding
  local col = (vim.fn.winnr() == 1 and (win_width + padding) or padding)
  local winid = vim.api.nvim_open_win(task:get_bufnr(), false, {
    relative = "editor",
    border = config.task_win.border,
    row = 1,
    col = col,
    width = width,
    height = vim.api.nvim_win_get_height(0),
    style = "minimal",
  })
  vim.api.nvim_win_set_option(winid, "previewwindow", true)
  for k, v in pairs(config.task_win.win_opts) do
    vim.api.nvim_win_set_option(winid, k, v)
  end
  if winid then
    util.scroll_to_end(winid)
  end
end

function Sidebar:change_task_detail(delta)
  local task = self:_get_task_from_line()
  if not task then
    return
  end
  local detail = self.task_detail[task.id] or self.default_detail
  self.task_detail[task.id] = math.max(MIN_DETAIL, math.min(MAX_DETAIL, detail + delta))
  task_list.update(task)
end

function Sidebar:change_default_detail(delta)
  self.default_detail = math.max(MIN_DETAIL, math.min(MAX_DETAIL, self.default_detail + delta))
  for i, v in pairs(self.task_detail) do
    if (delta < 0 and v > self.default_detail) or (delta > 0 and v < self.default_detail) then
      self.task_detail[i] = nil
    end
  end
  task_list.update()
end

function Sidebar:update_preview()
  local winid = util.get_preview_window()
  if not winid then
    return
  end
  local task = self:_get_task_from_line()
  if not task or not task:get_bufnr() or not vim.api.nvim_buf_is_valid(task:get_bufnr()) then
    local winbuf = vim.api.nvim_win_get_buf(winid)
    if vim.api.nvim_buf_get_option(winbuf, "buftype") == "terminal" then
      local scratch = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(scratch, 0, -1, true, { "--no terminal for task--" })
      vim.api.nvim_create_autocmd("BufLeave", {
        buffer = scratch,
        once = true,
        nested = true,
        callback = function()
          vim.api.nvim_buf_delete(scratch, {})
        end,
      })
      vim.api.nvim_win_set_buf(winid, scratch)
    end
    return
  end

  local preview_buf = vim.api.nvim_win_get_buf(winid)
  if preview_buf ~= task:get_bufnr() then
    vim.api.nvim_win_set_buf(winid, task:get_bufnr())
    util.scroll_to_end(winid)
  end
end

function Sidebar:jump(direction)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local prev = 1
  local cur = 1
  for _, v in ipairs(self.task_lines) do
    local next = v[1] + 2
    if v[1] >= lnum then
      if direction < 0 then
        vim.api.nvim_win_set_cursor(0, { prev, 0 })
      else
        pcall(vim.api.nvim_win_set_cursor, 0, { next, 0 })
      end
      return
    end
    prev = cur
    cur = next
  end
end

function Sidebar:run_action(name)
  vim.validate({ name = { name, "s", true } })
  local task = self:_get_task_from_line()
  if not task then
    return
  end

  action_util.run_task_action(task, name)
end

function Sidebar:render(tasks)
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return false
  end
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)

  local lines = {}
  local highlights = {}
  self.task_lines = {}
  -- Iterate backwards so we should most recent tasks first
  for i = #tasks, 1, -1 do
    local task = tasks[i]
    local detail = self.task_detail[task.id] or self.default_detail
    task:render(lines, highlights, detail)
    table.insert(self.task_lines, { #lines, task })
    if i > 1 then
      table.insert(lines, config.task_list.separator)
      table.insert(highlights, { "OverseerTaskBorder", #lines, 0, -1 })
    end
  end
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(self.bufnr, "modified", false)
  util.add_highlights(self.bufnr, ns, highlights)

  return true
end

return M
