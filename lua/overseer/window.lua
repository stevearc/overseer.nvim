local config = require("overseer.config")
local layout = require("overseer.layout")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local M = {}

local _winclosed_autocmd
local function watch_for_win_closed()
  if _winclosed_autocmd then
    return
  end
  _winclosed_autocmd = vim.api.nvim_create_autocmd("WinClosed", {
    desc = "Close overseer output window when task list is closed",
    callback = function(args)
      local winid = tonumber(args.match)
      local output_win = vim.w[winid].overseer_output_win
      if output_win and vim.api.nvim_win_is_valid(output_win) then
        vim.api.nvim_win_close(output_win, true)
      end
    end,
  })
end

---@param direction "left"|"right"|"bottom"
---@param existing_win integer
local function create_overseer_window(direction, existing_win)
  local bufnr = task_list.get_or_create_bufnr()

  local my_winid = vim.api.nvim_get_current_win()
  if existing_win then
    util.go_win_no_au(existing_win)
  else
    local split_direction = direction == "left" and "topleft" or "botright"
    vim.cmd.split({
      mods = { vertical = direction ~= "bottom", noautocmd = true, split = split_direction },
    })
  end
  local winid = vim.api.nvim_get_current_win()

  -- create the output window if we're opening on the bottom
  if direction == "bottom" then
    local output_win = vim.w.overseer_output_win
    if not output_win or not vim.api.nvim_win_is_valid(output_win) then
      vim.cmd.split({ mods = { vertical = true, noautocmd = true, split = "belowright" } })
      output_win = vim.api.nvim_get_current_win()
    end
    local last_task = task_list.list_tasks({ recent_first = true })[1]
    local outbuf = last_task and last_task:get_bufnr()
    if not outbuf or not vim.api.nvim_buf_is_valid(outbuf) then
      outbuf = vim.api.nvim_create_buf(false, true)
      vim.bo[outbuf].bufhidden = "wipe"
    end
    util.go_buf_no_au(outbuf)
    util.set_window_opts(config.task_list.output.win_opts, 0)
    util.go_win_no_au(winid)
    vim.w.overseer_output_win = output_win
    watch_for_win_closed()
  end

  util.go_buf_no_au(bufnr)
  util.set_window_opts(config.task_list.win_opts, 0)
  vim.api.nvim_win_set_width(0, layout.calculate_width(nil, config.task_list))
  if direction == "bottom" then
    vim.api.nvim_win_set_height(0, layout.calculate_height(nil, config.task_list))
  end
  -- Set the filetype only after we enter the buffer so that FileType autocmds
  -- behave properly
  vim.api.nvim_set_option_value("filetype", "OverseerList", { buf = bufnr })

  util.go_win_no_au(my_winid)
  return winid
end

M.get_win_id = function()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if vim.bo[bufnr].filetype == "OverseerList" then
      return winid
    end
  end
end

M.is_open = function()
  return M.get_win_id() ~= nil
end

---@class overseer.WindowOpts
---@field enter nil|boolean
---@field direction nil|"left"|"right"|"bottom"
---@field winid nil|integer Use this existing window instead of opening a new window

---@param opts? overseer.WindowOpts
M.open = function(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    enter = true,
    direction = config.task_list.direction,
  })
  local winid = M.get_win_id()
  if winid == nil then
    winid = create_overseer_window(opts.direction, opts.winid)
  end
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

---@param winid integer
---@return boolean
local function is_overseer_window(winid)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  if vim.bo[bufnr].filetype == "OverseerList" then
    return true
  elseif vim.b[bufnr].overseer_task then
    return true
  end
  return false
end

M.close = function()
  local winid = M.get_win_id()
  if winid then
    if winid == vim.api.nvim_get_current_win() then
      vim.cmd.wincmd({ args = { "p" } })
    end
    -- The sidebar is the last open window. Open a new window.
    local winids = vim.api.nvim_tabpage_list_wins(0)
    local overseer_wins = vim.tbl_filter(is_overseer_window, winids)
    if #winids == #overseer_wins then
      vim.cmd.new()
    end
    vim.api.nvim_win_close(winid, false)
  end
end

return M
