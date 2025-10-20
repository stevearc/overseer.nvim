local TaskView = require("overseer.task_view")
local action_util = require("overseer.action_util")
local binding_util = require("overseer.binding_util")
local bindings = require("overseer.task_list.bindings")
local config = require("overseer.config")
local layout = require("overseer.layout")
local task_list = require("overseer.task_list")
local util = require("overseer.util")

local M = {}

---@class overseer.Sidebar
---@field bufnr integer
---@field default_detail integer
---@field private task_lines {[1]: integer, [2]: overseer.Task}[]
---@field private task_detail table<integer, integer>
---@field private preview? overseer.TaskView
---@field private focused_task_id? integer
local Sidebar = {}

local ref

M.get_or_create = function()
  local sb = M.get()
  local created = not sb
  if not sb then
    ref = Sidebar.new()
    sb = ref
    sb:render(task_list.list_tasks())
  end
  return sb, created
end

M.get = function()
  if ref and vim.api.nvim_buf_is_loaded(ref.bufnr) and vim.api.nvim_buf_is_valid(ref.bufnr) then
    return ref
  end
end

local MIN_DETAIL = 1
local MAX_DETAIL = 3

function Sidebar.new()
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false

  local self = setmetatable({
    bufnr = bufnr,
    default_detail = config.task_list.default_detail,
    task_detail = {},
    task_lines = {},
    preview = nil,
  }, { __index = Sidebar })
  self:init()
  return self
end

---@private
function Sidebar:init()
  vim.api.nvim_create_autocmd({ "BufHidden", "WinLeave" }, {
    desc = "[Overseer] Close preview window when task list closes",
    buffer = self.bufnr,
    command = "pclose",
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    desc = "[Overseer] Clear state when task list buffer is unloaded",
    buffer = self.bufnr,
    callback = function()
      ref = nil
      return true
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    desc = "[Overseer] Update preview window when cursor moves",
    buffer = self.bufnr,
    nested = true,
    callback = function()
      local task = self:get_task_from_line()
      self:set_task_focused(task and task.id)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    pattern = "OverseerListUpdate",
    desc = "[Overseer] Update task list when tasks change",
    callback = function()
      self:render(task_list.list_tasks())
    end,
  })

  binding_util.create_plug_bindings(self.bufnr, bindings, self)
  binding_util.create_bindings_to_plug(self.bufnr, "n", config.task_list.bindings, "OverseerTask:")
end

---@private
---@return nil|integer
function Sidebar:get_winid()
  if vim.api.nvim_get_current_buf() == self.bufnr then
    return vim.api.nvim_get_current_win()
  end
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == self.bufnr then
      return winid
    end
  end
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == self.bufnr then
      return winid
    end
  end
end

---@private
---@param task_id? integer
function Sidebar:set_task_focused(task_id)
  if task_id == self.focused_task_id then
    return
  end
  vim.api.nvim_exec_autocmds("User", {
    pattern = "OverseerListTaskHover",
    modeline = false,
    data = {
      task_id = task_id,
    },
  })
  self.focused_task_id = task_id
  self:highlight_focused()
end

---@private
---@return nil|overseer.Task
function Sidebar:get_task_from_line(lnum)
  if not lnum then
    local winid = self:get_winid()
    if not winid then
      return nil
    end
    lnum = vim.api.nvim_win_get_cursor(winid)[1]
  end

  for _, v in ipairs(self.task_lines) do
    local end_lnum, task = v[1], v[2]
    if end_lnum >= lnum then
      return task
    end
  end
end

---@param task_id integer
function Sidebar:focus_task_id(task_id)
  local winid = self:get_winid()
  if not winid then
    return
  end
  local start_lnum = 1
  for _, v in ipairs(self.task_lines) do
    local end_lnum, task = v[1], v[2]
    if task.id == task_id then
      vim.api.nvim_win_set_cursor(winid, { start_lnum, 0 })
      self:set_task_focused(task_id)
      return
    end
    start_lnum = end_lnum + 2
  end
end

---@param bufnr integer
---@param winlayout nil|any
---@return nil|"left"|"right"|"bottom"
local function detect_direction(bufnr, winlayout)
  if not winlayout then
    winlayout = vim.fn.winlayout()
  end
  local type = winlayout[1]
  if type == "leaf" then
    if vim.api.nvim_win_get_buf(winlayout[2]) == bufnr then
      return "left"
    else
      return nil
    end
  else
    for i, nested in ipairs(winlayout[2]) do
      local dir = detect_direction(bufnr, nested)
      if dir then
        if type == "row" then
          return i == 1 and "left" or "right"
        else
          return "bottom"
        end
      end
    end
  end
end

function Sidebar:toggle_preview()
  if self.preview and not self.preview:is_disposed() then
    self.preview:dispose()
    return
  end

  local win_width = vim.api.nvim_win_get_width(0)
  local padding = 1
  local direction = detect_direction(self.bufnr) or "left"
  local width = layout.get_editor_width() - 2 - 2 * padding
  local height
  if direction ~= "bottom" then
    width = width - win_width
    height = vim.api.nvim_win_get_height(0) - 2
  else
    height = layout.get_editor_height() - vim.api.nvim_win_get_height(0) - 1 - 2 * padding
  end
  local col = (direction == "left" and (win_width + padding) or padding)
  local winid = vim.api.nvim_open_win(0, false, {
    relative = "editor",
    border = config.task_win.border,
    row = 1,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    noautocmd = true,
  })
  for k, v in pairs(config.task_win.win_opts) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
  end
  self.preview = TaskView.new(winid, {
    close_on_list_close = true,
    select = function(_, tasks, task_under_cursor)
      return task_under_cursor or tasks[1]
    end,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    desc = "Close task preview when leaving overseer list",
    once = true,
    callback = function()
      self.preview:dispose()
    end,
  })
  util.scroll_to_end(winid)
end

function Sidebar:change_task_detail(delta)
  local task = self:get_task_from_line()
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

---@private
---@return integer[]
function Sidebar:get_output_wins()
  local ret = {}
  for _, winid in ipairs(util.buf_list_wins(self.bufnr)) do
    local output_win = vim.w[winid].overseer_output_win
    if output_win and vim.api.nvim_win_is_valid(output_win) then
      table.insert(ret, output_win)
    end
  end
  return ret
end

---@private
function Sidebar:highlight_focused()
  local ns = vim.api.nvim_create_namespace("overseer_focus")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
  if not self.focused_task_id then
    return
  end

  local start_lnum = 1
  for _, v in ipairs(self.task_lines) do
    local end_lnum, task = v[1], v[2]
    if task.id == self.focused_task_id then
      if vim.fn.has("nvim-0.10") == 1 then
        vim.api.nvim_buf_set_extmark(self.bufnr, ns, start_lnum - 1, 0, {
          line_hl_group = "CursorLine",
          end_row = end_lnum - 1,
        })
      else
        for i = start_lnum, end_lnum do
          vim.api.nvim_buf_add_highlight(self.bufnr, ns, "CursorLine", i - 1, 0, -1)
        end
      end
    end
    start_lnum = end_lnum + 2
  end
end

function Sidebar:jump(direction)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local prev = 1
  local cur = 1
  for _, v in ipairs(self.task_lines) do
    local end_lnum = v[1]
    local next = end_lnum + 2
    if end_lnum >= lnum then
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

---@param direction integer -1 for up, 1 for down
function Sidebar:scroll_output(direction)
  if not self.focused_task_id then
    return
  end
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(winid) then
      local bufnr = vim.api.nvim_win_get_buf(winid)
      if vim.b[bufnr].overseer_task == self.focused_task_id then
        vim.api.nvim_win_call(winid, function()
          local key =
            vim.api.nvim_replace_termcodes(direction < 0 and "<C-u>" or "<C-d>", true, true, true)
          vim.cmd.normal({ args = { key }, bang = true })
        end)
      end
    end
  end
end

function Sidebar:run_action(name)
  vim.validate({ name = { name, "s", true } })
  local task = self:get_task_from_line()
  if not task then
    return
  end

  action_util.run_task_action(task, name)
end

function Sidebar:render(tasks)
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return false
  end
  local prev_num_lines = vim.api.nvim_buf_line_count(self.bufnr)
  local prev_first_task = self:get_task_from_line(1)
  local prev_first_task_id = prev_first_task and prev_first_task.id
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)

  local lines = {}
  local highlights = {}
  self.task_lines = {}
  local subtask_prefix = "▐ "
  -- Iterate backwards so we show most recent tasks first
  for i = #tasks, 1, -1 do
    local task = tasks[i]
    local detail = self.task_detail[task.id] or self.default_detail
    local start_idx = #lines + 1
    local hl_start_idx = #highlights + 1
    task:render(lines, highlights, detail)

    -- Indent subtasks
    if task.parent_id then
      for j = start_idx, #lines do
        lines[j] = subtask_prefix .. lines[j]
      end
      for j = hl_start_idx, #highlights do
        local hl = highlights[j]
        hl[3] = hl[3] + subtask_prefix:len()
        if hl[4] ~= -1 then
          hl[4] = hl[4] + subtask_prefix:len()
        end
        highlights[j] = hl
      end
      for j = start_idx, #lines do
        table.insert(highlights, { "OverseerTaskBorder", j, 0, subtask_prefix:len() })
      end
    end
    table.insert(self.task_lines, { #lines, task })
    if i > 1 then
      if tasks[i - 1].parent_id then
        table.insert(lines, subtask_prefix .. vim.fn.strcharpart(config.task_list.separator, 2))
      else
        table.insert(lines, config.task_list.separator)
      end
      table.insert(highlights, { "OverseerTaskBorder", #lines, 0, -1 })
    end
  end

  -- Attempting to render a newline within a line will cause a crash
  for i, line in ipairs(lines) do
    lines[i] = line:gsub("\n", " ")
  end

  local sidebar_winid = self:get_winid()
  local view
  if sidebar_winid then
    vim.api.nvim_win_call(sidebar_winid, function()
      view = vim.fn.winsaveview()
    end)
  end
  vim.bo[self.bufnr].modifiable = true
  -- pcall as updating buffer text in the background could fail with E565
  pcall(vim.api.nvim_buf_set_lines, self.bufnr, 0, -1, true, lines)
  vim.bo[self.bufnr].modifiable = false
  vim.bo[self.bufnr].modified = false
  util.add_highlights(self.bufnr, ns, highlights)

  if sidebar_winid then
    if view then
      vim.api.nvim_win_call(sidebar_winid, function()
        vim.fn.winrestview(view)
      end)
    end

    local new_first_task = tasks[#tasks]
    local new_first_task_id = new_first_task and new_first_task.id
    local new_line_count = vim.api.nvim_buf_line_count(self.bufnr)

    local in_sidebar = vim.api.nvim_get_current_win() == sidebar_winid
    local in_output_win = vim.b.overseer_task ~= nil
    if
      not in_sidebar
      and not in_output_win
      and prev_first_task_id ~= new_first_task_id
      and new_first_task_id
    then
      self:focus_task_id(new_first_task_id)
    elseif prev_num_lines ~= new_line_count then
      -- Make sure our cursor stays on the previously focused task, even if it's moved
      self:focus_task_id(self.focused_task_id)
    end
  end

  self:highlight_focused()

  return true
end

return M
