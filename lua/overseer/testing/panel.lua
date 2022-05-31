local config = require("overseer.config")
local data = require("overseer.testing.data")
local integrations = require("overseer.testing.integrations")
local util = require("overseer.util")
local utils = require("overseer.testing.utils")
local TEST_STATUS = data.TEST_STATUS
local M = {}

local function render_summary(summary, lnum, col_start)
  lnum = lnum or 1
  col_start = col_start or 0
  local pieces = {}
  local highlights = {}
  for _, v in ipairs(TEST_STATUS.values) do
    if summary[v] > 0 then
      local icon = config.test_icons[v]
      table.insert(pieces, string.format("%s%d", icon, summary[v]))
      local col_end = col_start + string.len(pieces[#pieces]) + 1
      table.insert(highlights, {
        string.format("OverseerTest%s", v),
        lnum,
        col_start,
        col_end,
      })
      col_start = col_end
    end
  end
  return table.concat(pieces, " "), highlights
end

local function get_path(obj, path, max)
  for i, v in ipairs(path) do
    obj = obj[v]
    if max and i >= max then
      break
    end
  end
  return obj
end

local reverse_map = {}
local function render(bufnr)
  reverse_map = {}
  local lines = {}
  local highlights = {}
  local current_path = {}
  local results = data.get_workspace_results()
  local total_summary, sum_hl = render_summary(results.summaries["_"])
  table.insert(lines, total_summary)
  vim.list_extend(highlights, sum_hl)
  for _, result in ipairs(results.tests) do
    for i, v in ipairs(result.path) do
      if not current_path[i] or current_path[i] ~= v then
        current_path[i] = v
        local sum = get_path(results.summaries, current_path, i)
        local status = sum:get_status()
        local icon = config.test_icons[status]
        local padding = string.rep("  ", i - 1)
        table.insert(lines, string.format("%s%s%s", padding, icon, v))
        table.insert(highlights, {
          string.format("OverseerTest%s", status),
          #lines,
          0,
          string.len(padding) + string.len(icon),
        })
        reverse_map[#lines] = {
          type = "group",
          path = util.tbl_slice(current_path, 1, i),
        }
      end
    end
    while #current_path > #result.path do
      table.remove(current_path)
    end

    local icon = config.test_icons[result.status]
    local padding = string.rep("  ", #result.path)
    table.insert(lines, string.format("%s%s%s", padding, icon, result.name))
    table.insert(highlights, {
      string.format("OverseerTest%s", result.status),
      #lines,
      0,
      string.len(padding) + string.len(icon),
    })
    reverse_map[#lines] = {
      type = "test",
      test = result,
    }
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local ns = vim.api.nvim_create_namespace("OverseerTest")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    local group, lnum, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(bufnr, ns, group, lnum - 1, col_start, col_end)
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
  update()

  vim.keymap.set("n", "<C-r>", function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local entry = reverse_map[lnum]
    if entry and entry.type == "test" then
      local test = entry.test
      local integ = integrations.get_by_name(test.integration)
      -- TODO don't duplicate this logic
      data.reset_test_status(test.id)
      utils.create_and_start_task(
        integ.name,
        integ:run_test_in_file(vim.api.nvim_buf_get_name(bufnr), test)
      )
      data.touch()
    end
  end, { buffer = bufnr })

  vim.keymap.set("n", "<C-s>", function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local entry = reverse_map[lnum]
    if entry and entry.type == "test" then
      local test = entry.test
      if test.stacktrace then
        vim.fn.setqflist(test.stacktrace)
      end
    end
  end, { buffer = bufnr })

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
