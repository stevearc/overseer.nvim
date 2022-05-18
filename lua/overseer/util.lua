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
  vim.api.nvim_win_set_cursor(winid, {lnum, 0})
end

M.get_preview_window = function()
  for _,winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_option(winid, 'previewwindow') then
      return winid
    end
  end
end

M.get_stdout_line_iter = function()
  local pending = ""
  return function(data)
    local ret = {}
    local last = #data
    for i, chunk in ipairs(data) do
      if chunk == '' then
        if pending ~= "" then
          table.insert(ret, pending)
        end
        pending = ""
      else
        -- No carriage returns plz
        chunk = string.gsub(chunk, '\r', '')
        if i ~= last then
          table.insert(ret, pending .. chunk)
          pending = ''
        else
          pending = chunk
        end
      end
    end
    return ret
  end
end

return M
