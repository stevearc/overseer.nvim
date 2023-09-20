local action_util = require("overseer.action_util")
local bindings = require("overseer.task_list.bindings")
local binding_util = require("overseer.binding_util")
local config = require("overseer.config")
local layout = require("overseer.layout")
local task_list = require("overseer.task_list")
local util = require("overseer.util")

local M = {}

local Sidebar = {}

local ref

M.get_or_create = function()
  local sb = M.get()
  local created = not sb
  if not sb then
    ref = Sidebar.new()
    sb = ref
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

---@return nil|integer
function Sidebar:_get_winid()
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

---@return nil|overseer.Task
function Sidebar:_get_task_from_line(lnum)
  if not lnum then
    local winid = self:_get_winid()
    if not winid then
      return nil
    end
    lnum = vim.api.nvim_win_get_cursor(winid)[1]
  end

  for _, v in ipairs(self.task_lines) do
    if v[1] >= lnum then
      return v[2]
    end
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
  local pwin = util.get_preview_window()
  if pwin then
    vim.cmd.pclose()
    return
  end
  local task = self:_get_task_from_line()
  local task_bufnr = task and task:get_bufnr()
  if not task or not task_bufnr or not vim.api.nvim_buf_is_valid(task_bufnr) then
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
  local winid = vim.api.nvim_open_win(task_bufnr, false, {
    relative = "editor",
    border = config.task_win.border,
    row = 1,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    noautocmd = true,
  })
  vim.api.nvim_set_option_value("previewwindow", true, { scope = "local", win = winid })
  for k, v in pairs(config.task_win.win_opts) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
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

---@return integer[]
function Sidebar:_get_output_wins()
  local ret = {}
  for _, winid in ipairs(util.buf_list_wins(self.bufnr)) do
    local output_win = vim.w[winid].overseer_output_win
    if output_win and vim.api.nvim_win_is_valid(output_win) then
      table.insert(ret, output_win)
    end
  end
  return ret
end

---@return integer[]
function Sidebar:_get_preview_wins()
  local ret = {}
  local preview_win = util.get_preview_window()
  if preview_win then
    table.insert(ret, preview_win)
  end
  for _, winid in ipairs(self:_get_output_wins()) do
    table.insert(ret, winid)
  end
  return ret
end

function Sidebar:update_preview()
  local winids = self:_get_preview_wins()
  if vim.tbl_isempty(winids) then
    return
  end
  local task = self:_get_task_from_line()
  local display_buf = task and task:get_bufnr()
  if not display_buf or not vim.api.nvim_buf_is_valid(display_buf) then
    display_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[display_buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(display_buf, 0, -1, true, { "--no task buffer--" })
    if task then
      -- The task hasn't started yet and doesn't have a buffer.
      -- Add a callback to retry once the task does start
      task:subscribe("on_start", function()
        self:update_preview()
        return false
      end)
    end
  end

  for _, winid in ipairs(winids) do
    if vim.api.nvim_win_get_buf(winid) ~= display_buf then
      vim.api.nvim_win_set_buf(winid, display_buf)
      util.scroll_to_end(winid)
    end
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

---@param direction integer -1 for up, 1 for down
function Sidebar:scroll_output(direction)
  local wins = self:_get_preview_wins()
  for _, winid in ipairs(wins) do
    vim.api.nvim_win_call(winid, function()
      local key =
        vim.api.nvim_replace_termcodes(direction < 0 and "<C-u>" or "<C-d>", true, true, true)
      vim.cmd.normal({ args = { key }, bang = true })
    end)
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
  local prev_first_task = self:_get_task_from_line(1)
  local prev_first_task_id = prev_first_task and prev_first_task.id
  local new_first_task_id = not vim.tbl_isempty(tasks) and tasks[#tasks].id
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
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(self.bufnr, "modified", false)
  util.add_highlights(self.bufnr, ns, highlights)

  if prev_first_task_id ~= new_first_task_id then
    local output_wins = self:_get_output_wins()
    local has_output_wins = not vim.tbl_isempty(output_wins)
    local in_sidebar = vim.api.nvim_get_current_buf() == self.bufnr
    local in_output_win = vim.tbl_contains(output_wins, vim.api.nvim_get_current_win())
    if has_output_wins and not in_sidebar and not in_output_win then
      for _, winid in ipairs(util.buf_list_wins(self.bufnr)) do
        vim.api.nvim_win_set_cursor(winid, { 1, 0 })
      end
      self:update_preview()
    end
  end

  return true
end

return M
