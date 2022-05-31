local data = require("overseer.testing.data")
local util = require("overseer.util")
local TEST_STATUS = data.TEST_STATUS
local M = {}

local status_icons = {
  [TEST_STATUS.NONE] = " ",
  [TEST_STATUS.RUNNING] = " ",
  [TEST_STATUS.SUCCESS] = " ",
  [TEST_STATUS.FAILURE] = " ",
  [TEST_STATUS.SKIPPED] = " ",
}

local reverse_map = {}
local function render(bufnr)
  reverse_map = {}
  local lines = {}
  local highlights = {}
  local current_path = {}
  for _, result in ipairs(data.get_workspace_results()) do
    for i, v in ipairs(result.path) do
      if not current_path[i] or current_path[i] ~= v then
        table.insert(lines, string.format("%s%s", string.rep("  ", i), v))
        current_path[i] = v
      end
    end
    while #current_path > #result.path do
      table.remove(current_path)
    end

    local icon = status_icons[result.status]
    local padding = string.rep("  ", #result.path)
    table.insert(lines, string.format("%s%s%s", padding, icon, result.name))
    table.insert(highlights, {
      group = string.format("OverseerTest%s", result.status),
      row = #lines,
      col_start = 0,
      col_end = string.len(padding) + string.len(icon),
    })
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local ns = vim.api.nvim_create_namespace("OverseerTest")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl.group, hl.row - 1, hl.col_start, hl.col_end)
  end
end

local function create_test_panel_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local update = function()
    render(bufnr)
  end

  data.add_callback(update)
  vim.api.nvim_create_autocmd("BufUnload", {
    callback = function()
      data.remove_callback(update)
    end,
    buffer = bufnr,
    once = true,
    nested = true,
  })
  return bufnr
end

local function create_test_panel_win()
  local bufnr = create_test_panel_buf()

  local my_winid = vim.api.nvim_get_current_win()
  local direction = "left"
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

  util.go_buf_no_au(bufnr)
  vim.api.nvim_win_set_option(0, "winfixwidth", true)
  vim.api.nvim_win_set_option(0, "number", false)
  vim.api.nvim_win_set_option(0, "signcolumn", "no")
  vim.api.nvim_win_set_option(0, "foldcolumn", "0")
  vim.api.nvim_win_set_option(0, "relativenumber", false)
  vim.api.nvim_win_set_option(0, "wrap", false)
  vim.api.nvim_win_set_option(0, "spell", false)
  vim.api.nvim_win_set_width(0, 80)
  -- Set the filetype only after we enter the buffer so that FileType autocmds
  -- behave properly
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerTestPanel")

  local winid = vim.api.nvim_get_current_win()
  util.go_win_no_au(my_winid)
  return winid
end

M.get_win_id = function()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if vim.api.nvim_buf_get_option(bufnr, "filetype") == "OverseerTestPanel" then
      return winid
    end
  end
end

M.is_open = function()
  return M.get_win_id() ~= nil
end

M.open = function()
  if M.is_open() then
    return
  end
  local winid = create_test_panel_win()
  vim.api.nvim_set_current_win(winid)
end

M.toggle = function()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

M.close = function()
  local winid = M.get_win_id()
  if winid then
    vim.api.nvim_win_close(winid, false)
  end
end

return M
