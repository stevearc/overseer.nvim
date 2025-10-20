local TaskView = require("overseer.task_view")
local action_util = require("overseer.action_util")
local config = require("overseer.config")
local keymap_util = require("overseer.keymap_util")
local layout = require("overseer.layout")
local task_list = require("overseer.task_list")
local util = require("overseer.util")

local M = {}

---@class overseer.Sidebar
---@field bufnr integer
---@field private task_lines {[1]: integer, [2]: integer, [3]: overseer.Task}[]
---@field private preview? overseer.TaskView
---@field private focused_task_id? integer
---@field private list_task_opts overseer.ListTaskOpts
local Sidebar = {}

local ref

---@return overseer.Sidebar
---@return boolean
M.get_or_create = function()
  local sb = M.get()
  local created = not sb
  if not sb then
    sb = Sidebar.new()
    ref = sb
    sb:render()
  end
  return sb, created
end

---@return nil|overseer.Sidebar
M.get = function()
  if ref and vim.api.nvim_buf_is_loaded(ref.bufnr) and vim.api.nvim_buf_is_valid(ref.bufnr) then
    return ref
  end
end

---@return overseer.Sidebar
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
    task_lines = {},
    preview = nil,
    list_task_opts = { include_ephemeral = true, sort = config.task_list.sort },
  }, { __index = Sidebar })
  self:init()
  ---@cast self overseer.Sidebar
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
      self:render()
    end,
  })

  local periodic_update
  periodic_update = function()
    if not vim.api.nvim_buf_is_valid(self.bufnr) then
      return
    end
    -- only rerender if the buffer is visible
    if self:get_winid() then
      self:render()
    end
    vim.defer_fn(periodic_update, 1000) -- update every second
  end
  periodic_update()

  keymap_util.set_keymaps(config.task_list.keymaps, self.bufnr)
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
---@return nil|integer offset
function Sidebar:get_task_from_line(lnum)
  if not lnum then
    local winid = self:get_winid()
    if not winid then
      return nil, nil
    end
    lnum = vim.api.nvim_win_get_cursor(winid)[1]
  end

  for _, v in ipairs(self.task_lines) do
    local start_lnum, last_lnum, task = v[1], v[2], v[3]
    if lnum <= last_lnum then
      return task, lnum - start_lnum
    end
  end
end

---@param task_id integer
---@param offset? integer
function Sidebar:focus_task_id(task_id, offset)
  local winid = self:get_winid()
  if not winid then
    return
  end
  offset = offset or 0
  for _, v in ipairs(self.task_lines) do
    local start_line, task = v[1], v[3]
    if task.id == task_id then
      pcall(vim.api.nvim_win_set_cursor, winid, { start_line + offset, 0 })
      self:set_task_focused(task_id)
      return
    end
  end
end

---@param bufnr integer
---@param winlayout? vim.fn.winlayout.branch|vim.fn.winlayout.leaf|vim.fn.winlayout.empty
---@return nil|"left"|"right"|"bottom"
local function detect_direction(bufnr, winlayout)
  if not winlayout then
    winlayout = vim.fn.winlayout()
  end
  local type = winlayout[1]
  if type == "leaf" then
    ---@cast winlayout vim.fn.winlayout.leaf
    if vim.api.nvim_win_get_buf(winlayout[2]) == bufnr then
      return "left"
    else
      return nil
    end
  else
    ---@cast winlayout vim.fn.winlayout.branch
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
  if self.preview and not self.preview:is_win_closed() then
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
    list_task_opts = self.list_task_opts,
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

  for _, v in ipairs(self.task_lines) do
    local start_lnum, end_lnum, task = v[1], v[2], v[3]
    if task.id == self.focused_task_id then
      vim.api.nvim_buf_set_extmark(self.bufnr, ns, start_lnum - 1, 0, {
        line_hl_group = "CursorLine",
        end_row = end_lnum - 1,
      })
    end
  end
end

function Sidebar:jump(direction)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  for i, v in ipairs(self.task_lines) do
    local first_line = v[1]
    if first_line <= lnum then
      if direction < 0 and i > 1 then
        local new_lnum = self.task_lines[i - 1][1]
        vim.api.nvim_win_set_cursor(0, { new_lnum, 0 })
      elseif direction > 0 and i < #self.task_lines then
        local new_lnum = self.task_lines[i + 1][1]
        vim.api.nvim_win_set_cursor(0, { new_lnum, 0 })
      end
      return
    end
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
  local task = self:get_task_from_line()
  if not task then
    return
  end

  action_util.run_task_action(task, name)
end

function Sidebar:toggle_show_wrapped()
  self.list_task_opts.wrapped = not self.list_task_opts.wrapped
  self:render()
end

function Sidebar:render()
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return false
  end
  local tasks = task_list.list_tasks(self.list_task_opts)
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)

  local lines = {}
  local extmarks = {}
  self.task_lines = {}
  -- virtual text lines for separating processes
  local border = "OverseerTaskBorder"
  local tl = config.task_list
  local sep_lines = { { { tl.separator, border } } }
  local child_indent = { tl.child_indent[1], border }
  local child_sep_1 = { { { tl.child_indent[2], border }, { tl.separator, border } } }
  local child_sep_2 = { { { tl.child_indent[3], border }, { tl.separator, border } } }

  -- Iterate backwards so we show most recent tasks first
  for i, task in ipairs(tasks) do
    local line_start = #lines + 1
    local task_lines = config.task_list.render(task)

    -- Indent subtasks
    if task.parent_id then
      for j = 1, #task_lines do
        table.insert(task_lines[j], 1, child_indent)
      end
    end

    vim.list_extend(lines, task_lines)
    table.insert(self.task_lines, { line_start, #lines, task })

    -- task separator
    if i < #tasks then
      local prev_is_child = i > 1 and tasks[i - 1].parent_id ~= nil
      local next_is_child = tasks[i + 1].parent_id ~= nil
      if next_is_child then
        table.insert(extmarks, { #lines - 1, 0, { virt_lines = child_sep_1 } })
      elseif prev_is_child then
        table.insert(extmarks, { #lines - 1, 0, { virt_lines = child_sep_2 } })
      else
        table.insert(extmarks, { #lines - 1, 0, { virt_lines = sep_lines } })
      end
    end
  end

  util.render_buf_chunks(self.bufnr, ns, lines)
  for _, extmark in ipairs(extmarks) do
    vim.api.nvim_buf_set_extmark(self.bufnr, ns, extmark[1], extmark[2], extmark[3])
  end

  local sidebar_winid = self:get_winid()
  if sidebar_winid then
    local cursor = vim.api.nvim_win_get_cursor(sidebar_winid)
    local task, offset = self:get_task_from_line(cursor[1])
    if task then
      self:focus_task_id(task.id, offset)
    end
  end

  self:highlight_focused()

  return true
end

return M
