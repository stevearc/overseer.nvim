local config = require("overseer.config")
local layout = require("overseer.layout")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local M = {}

---@param direction "left"|"right"
---@param existing_win integer
local function create_overseer_window(direction, existing_win)
  local bufnr = task_list.get_or_create_bufnr()

  local my_winid = vim.api.nvim_get_current_win()
  if existing_win then
    util.go_win_no_au(existing_win)
  else
    local modifier = direction == "left" and "topleft" or "botright"
    local winids = util.get_fixed_wins(bufnr)
    local split_target
    if direction == "left" then
      split_target = winids[1]
    else
      split_target = winids[#winids]
    end
    if my_winid ~= split_target then
      util.go_win_no_au(split_target)
    end
    vim.cmd(string.format("noau vertical %s split", modifier))
  end

  util.go_buf_no_au(bufnr)
  vim.api.nvim_win_set_option(0, "listchars", "tab:> ")
  vim.api.nvim_win_set_option(0, "winfixwidth", true)
  vim.api.nvim_win_set_option(0, "number", false)
  vim.api.nvim_win_set_option(0, "signcolumn", "no")
  vim.api.nvim_win_set_option(0, "foldcolumn", "0")
  vim.api.nvim_win_set_option(0, "relativenumber", false)
  vim.api.nvim_win_set_option(0, "wrap", false)
  vim.api.nvim_win_set_option(0, "spell", false)
  vim.api.nvim_win_set_width(0, layout.calculate_width(nil, config.task_list))
  -- Set the filetype only after we enter the buffer so that FileType autocmds
  -- behave properly
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerList")

  local winid = vim.api.nvim_get_current_win()
  util.go_win_no_au(my_winid)
  return winid
end

M.get_win_id = function()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if vim.api.nvim_buf_get_option(bufnr, "filetype") == "OverseerList" then
      return winid
    end
  end
end

M.is_open = function()
  return M.get_win_id() ~= nil
end

---@class overseer.WindowOpts
---@field enter nil|boolean
---@field direction nil|"left"|"right"
---@field winid nil|integer Use this existing window instead of opening a new window

---@param opts? overseer.WindowOpts
M.open = function(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    enter = true,
    direction = config.task_list.direction,
  })
  if M.is_open() then
    return
  end
  local winid = create_overseer_window(opts.direction, opts.winid)
  if opts.enter then
    vim.api.nvim_set_current_win(winid)
  end
end

---@param opts? overseer.WindowOpts
M.toggle = function(opts)
  if M.is_open() then
    M.close()
  else
    M.open(opts)
  end
end

M.close = function()
  local winid = M.get_win_id()
  if winid then
    vim.api.nvim_win_close(winid, false)
  end
end

return M
