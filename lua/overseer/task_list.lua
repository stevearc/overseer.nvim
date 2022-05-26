local actions = require("overseer.actions")
local config = require("overseer.config")
local registry = require("overseer.registry")
local util = require("overseer.util")
local M = {}

local TaskList = {}

local ref

M.keys = {
  {
    lhs = "g?",
    mode = "n",
    desc = "Open task action menu",
    rhs = function(task_list)
      task_list:run_action()
    end,
  },
  {
    lhs = "<CR>",
    mode = "n",
    desc = "Open task action menu",
    rhs = function(task_list)
      task_list:run_action()
    end,
  },
  {
    lhs = "e",
    mode = "n",
    desc = "Edit task",
    rhs = function(task_list)
      task_list:run_action("edit")
    end,
  },
  {
    lhs = "o",
    mode = "n",
    desc = "Open task terminal in current window",
    rhs = function(task_list)
      task_list:open_buffer()
    end,
  },
  {
    lhs = "v",
    mode = "n",
    desc = "Open task terminal in a vsplit",
    rhs = function(task_list)
      task_list:open_buffer("vsplit")
    end,
  },
  {
    lhs = "f",
    mode = "n",
    desc = "Open task terminal in a floating window",
    rhs = function(task_list)
      task_list:run_action("open fullscreen")
    end,
  },
  {
    lhs = "p",
    mode = "n",
    desc = "Toggle task terminal in a preview window",
    rhs = function(task_list)
      task_list:toggle_preview()
    end,
  },
  {
    lhs = "l",
    mode = "n",
    desc = "Increase task detail level",
    rhs = function(task_list)
      task_list:change_task_detail(1)
    end,
  },
  {
    lhs = "h",
    mode = "n",
    desc = "Decrease task detail level",
    rhs = function(task_list)
      task_list:change_task_detail(-1)
    end,
  },
  {
    lhs = "L",
    mode = "n",
    desc = "Increase all task detail levels",
    rhs = function(task_list)
      task_list:change_default_detail(1)
    end,
  },
  {
    lhs = "H",
    mode = "n",
    desc = "Decrease all task detail levels",
    rhs = function(task_list)
      task_list:change_default_detail(-1)
    end,
  },
  {
    lhs = "[",
    mode = "n",
    desc = "Decrease window width",
    rhs = function()
      local width = vim.api.nvim_win_get_width(0)
      vim.api.nvim_win_set_width(0, math.max(10, width - 10))
    end,
  },
  {
    lhs = "]",
    mode = "n",
    desc = "Increase window width",
    rhs = function()
      local width = vim.api.nvim_win_get_width(0)
      vim.api.nvim_win_set_width(0, math.max(10, width + 10))
    end,
  },
}

M.show = function()
  local lhs = {}
  local rhs = {}
  local max_left = 1
  for _, binding in ipairs(M.keys) do
    local keys, _, desc = unpack(binding)
    if type(keys) ~= "table" then
      keys = { keys }
    end
    local keystr = table.concat(keys, "/")
    max_left = math.max(max_left, vim.api.nvim_strwidth(keystr))
    table.insert(lhs, keystr)
    table.insert(rhs, desc)
  end

  local lines = {}
  local max_line = 1
  for i = 1, #lhs do
    local left = lhs[i]
    local right = rhs[i]
    local line = string.format(" %s   %s", util.rpad(left, max_left), right)
    max_line = math.max(max_line, vim.api.nvim_strwidth(line))
    table.insert(lines, line)
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local ns = vim.api.nvim_create_namespace("AerialKeymap")
  for i = 1, #lhs do
    vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
      end_col = max_left + 1,
      hl_group = "Special",
    })
  end
  local opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "<cmd>close<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<c-c>", "<cmd>close<CR>", opts)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight
  vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = math.max(0, (editor_height - #lines) / 2),
    col = math.max(0, (editor_width - max_line - 1) / 2),
    width = math.min(editor_width, max_line + 1),
    height = math.min(editor_height, #lines),
    zindex = 150,
    style = "minimal",
    border = "rounded",
  })
end

M.get_or_create = function()
  if not ref then
    ref = TaskList.new()
  end
  return ref
end

local MIN_DETAIL = 1
local MAX_DETAIL = 3

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
    default_detail = 1,
    task_detail = {},
    task_lines = {},
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

  for _, binding in ipairs(M.keys) do
    for _, lhs in util.iter_as_list(binding.lhs) do
      vim.keymap.set(binding.mode, lhs, function()
        binding.rhs(tl)
      end, { buffer = bufnr, desc = binding.desc })
    end
  end

  ref = tl
  return tl
end

function TaskList:_get_task_from_line(lnum)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  -- TODO could do binary search here
  for _, v in ipairs(self.task_lines) do
    if v[1] >= lnum then
      return v[2]
    end
  end
end

function TaskList:toggle_preview()
  local pwin = util.get_preview_window()
  if pwin then
    vim.cmd([[pclose]])
    return
  end
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
    return
  end

  local winid = self:open_float(task.bufnr, false)
  vim.api.nvim_win_set_option(winid, "previewwindow", true)
  if winid then
    util.scroll_to_end(winid)
  end
end

function TaskList:change_task_detail(delta)
  local task = self:_get_task_from_line()
  if not task then
    return
  end
  local detail = self.task_detail[task.id] or self.default_detail
  self.task_detail[task.id] = math.max(MIN_DETAIL, math.min(MAX_DETAIL, detail + delta))
  registry.update_task(task)
end

function TaskList:change_default_detail(delta)
  self.default_detail = math.max(MIN_DETAIL, math.min(MAX_DETAIL, self.default_detail + delta))
  for i, v in pairs(self.task_detail) do
    if (delta < 0 and v > self.default_detail) or (delta > 0 and v < self.default_detail) then
      self.task_detail[i] = nil
    end
  end
  registry.update()
end

function TaskList:update_preview()
  local winid = util.get_preview_window()
  if not winid then
    return
  end
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
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
  if preview_buf ~= task.bufnr then
    vim.api.nvim_win_set_buf(winid, task.bufnr)
    util.scroll_to_end(winid)
  end
end

function TaskList:open_float(bufnr, enter)
  local width = vim.o.columns - vim.api.nvim_win_get_width(0)
  local col = vim.fn.winnr() == 1 and width or 0
  local winid = vim.api.nvim_open_win(bufnr, enter, {
    relative = "editor",
    row = 1,
    col = col,
    width = width,
    height = vim.api.nvim_win_get_height(0),
    style = "minimal",
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    desc = "Close float on BufLeave",
    buffer = bufnr,
    once = true,
    nested = true,
    callback = function()
      pcall(vim.api.nvim_win_close, winid, true)
    end,
  })
  return winid
end

function TaskList:open_buffer(direction)
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
    return
  end

  if direction == "vsplit" then
    vim.cmd([[vsplit]])
    vim.api.nvim_win_set_buf(0, task.bufnr)
  else
    vim.cmd([[normal! m']])
    vim.api.nvim_win_set_buf(0, task.bufnr)
  end
  util.scroll_to_end(0)
end

function TaskList:run_action(name)
  vim.validate({ name = { name, "s", true } })
  local task = self:_get_task_from_line()
  if not task then
    return
  end

  actions.run_action(task, name)
end

function TaskList:render(tasks)
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return false
  end
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)

  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
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
      table.insert(lines, config.list_sep)
      table.insert(highlights, { "OverseerTaskBorder", #lines, 0, -1 })
    end
  end
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(self.bufnr, "modified", false)
  for _, hl in ipairs(highlights) do
    local group, row, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(self.bufnr, ns, group, row - 1, col_start, col_end)
  end

  return true
end

M.new = TaskList.new

M.register_action = function(...)
  local tl = M.get_or_create()
  tl:register_action(...)
end

return M
