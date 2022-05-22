local M = {}

M.is_floating_win = function(winid)
  return vim.api.nvim_win_get_config(winid or 0).relative ~= ""
end

M.get_fixed_wins = function(bufnr)
  local wins = {}
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not M.is_floating_win(winid) and (not bufnr or vim.api.nvim_win_get_buf(winid) == bufnr) then
      table.insert(wins, winid)
    end
  end
  return wins
end

M.go_win_no_au = function(winid)
  if winid == nil or winid == vim.api.nvim_get_current_win() then
    return
  end
  local winnr = vim.api.nvim_win_get_number(winid)
  vim.cmd(string.format("noau %dwincmd w", winnr))
end

M.go_buf_no_au = function(bufnr)
  vim.cmd(string.format("noau b %d", bufnr))
end

M.scroll_to_end = function(winid)
  winid = winid or 0
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local lnum = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(winid, { lnum, 0 })
end

M.add_highlights = function(bufnr, ns, highlights)
  for _, hl in ipairs(highlights) do
    local group, lnum, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(bufnr, ns, group, lnum - 1, col_start, col_end)
  end
end

M.align = function(text, width, alignment)
  if alignment == "center" then
    local padding = math.floor((width - string.len(text)) / 2)
    return string.rep(" ", padding) .. text
  elseif alignment == "right" then
    local padding = width - string.len(text)
    return string.rep(" ", padding) .. text
  else
    return text
  end
end

M.get_preview_window = function()
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_option(winid, "previewwindow") then
      return winid
    end
  end
end

M.list_to_map = function(list)
  local map = {}
  for _, v in ipairs(list) do
    map[v] = true
  end
  return map
end

M.leave_insert = function()
  if vim.api.nvim_get_mode().mode:match("^i") then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
  end
end

M.tbl_index = function(tbl, needle, extract)
  for i, v in ipairs(tbl) do
    if extract then
      if extract(v) == needle then
        return i
      end
    else
      if v == needle then
        return i
      end
    end
  end
end

M.get_stdout_line_iter = function()
  local pending = ""
  return function(data)
    local ret = {}
    local last = #data
    for i, chunk in ipairs(data) do
      if chunk == "" then
        if pending ~= "" then
          table.insert(ret, pending)
        end
        pending = ""
      else
        -- No carriage returns plz
        chunk = string.gsub(chunk, "\r$", "")
        if i ~= last then
          table.insert(ret, pending .. chunk)
          pending = ""
        else
          pending = chunk
        end
      end
    end
    return ret
  end
end

M.pwrap = function(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      vim.api.nvim_err_writeln(err)
    end
  end
end

-- Attempt to detect if a command should be run by the shell (passed as string
-- to termopen)  or if it can be run directly (passed as list to termopen)
M.is_shell_cmd = function(cmd)
  for arg in vim.gsplit(cmd, "%s+") do
    if arg == "|" or arg == "||" or arg == "&&" then
      return true
    end
  end
  return false
end

return M
