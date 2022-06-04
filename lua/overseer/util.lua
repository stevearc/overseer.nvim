local hsluv = require("overseer.hsluv")
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

M.find_code_window = function()
  if vim.api.nvim_buf_get_option(0, "buftype") == "" then
    return vim.api.nvim_get_current_win()
  end
  for _, winid in ipairs(M.get_fixed_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if vim.api.nvim_buf_get_option(bufnr, "buftype") == "" then
      return winid
    end
  end
  return 0
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

M.ljust = function(text, size)
  local len = vim.api.nvim_strwidth(text)
  if len < size then
    return string.format("%s%s", text, string.rep(" ", size - len))
  end
  return text
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
  if type(list) == "string" then
    map[list] = true
  else
    for _, v in ipairs(list) do
      map[v] = true
    end
  end
  return map
end

M.leave_insert = function()
  if vim.api.nvim_get_mode().mode:match("^i") then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
  end
end

M.tbl_reverse = function(tbl)
  local len = #tbl
  for i = 1, math.floor(len / 2) do
    local j = len - i + 1
    local swp = tbl[i]
    tbl[i] = tbl[j]
    tbl[j] = swp
  end
  return tbl
end

M.tbl_slice = function(tbl, start_idx, end_idx)
  local ret = {}
  if not start_idx then
    start_idx = 1
  end
  if not end_idx then
    end_idx = #tbl
  end
  for i = start_idx, end_idx do
    table.insert(ret, tbl[i])
  end
  return ret
end

M.tbl_remove = function(tbl, needle, transform)
  for i, v in ipairs(tbl) do
    if transform then
      if transform(v) == needle then
        return table.remove(tbl, i)
      end
    elseif v == needle then
      return table.remove(tbl, i)
    end
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

M.remove_ansi = function(str)
  return str:gsub("\x1b%[[%d;]*%dm", "")
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
        chunk = M.remove_ansi(chunk)
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

M.list_any = function(list, cb)
  for _, v in ipairs(list) do
    if cb(v) then
      return true
    end
  end
  return false
end

M.tbl_group_by = function(list, key)
  local ret = {}
  for _, v in ipairs(list) do
    if not ret[v[key]] then
      ret[v[key]] = {}
    end
    table.insert(ret[v[key]], v)
  end
  return ret
end

M.iter_as_list = function(list_or_obj)
  if list_or_obj == nil then
    return function() end
  end
  if type(list_or_obj) ~= "table" then
    local i = 0
    return function()
      if i == 0 then
        i = i + 1
        return i, list_or_obj
      end
    end
  else
    return ipairs(list_or_obj)
  end
end

M.pack = function(...)
  return { n = select("#", ...), ... }
end

local bufenter_callbacks = {}
M.set_bufenter_callback = function(bufnr, key, callback)
  local cbs = bufenter_callbacks[bufnr]
  if not cbs then
    cbs = {}
    bufenter_callbacks[bufnr] = cbs
  end
  if cbs[key] then
    vim.api.nvim_del_autocmd(cbs[key])
  end
  cbs[key] = vim.api.nvim_create_autocmd("BufEnter", {
    desc = "Set overseer test diagnostics on first enter",
    callback = function()
      cbs[key] = nil
      if vim.tbl_isempty(bufenter_callbacks[bufnr]) then
        bufenter_callbacks[bufnr] = nil
      end
      callback(bufnr)
    end,
    buffer = bufnr,
    once = true,
    nested = true,
  })
end

M.run_once_buf_loaded = function(bufnr, key, callback)
  if vim.api.nvim_buf_is_loaded(bufnr) then
    callback(bufnr)
  else
    M.set_bufenter_callback(bufnr, key, callback)
  end
end

M.get_group_attr = function(group, what)
  local id = vim.fn.synIDtrans(vim.fn.hlID(group))
  return vim.fn.synIDattr(id, what, "gui")
end

M.get_group_fg = function(group)
  local attr = M.get_group_attr(group, "fg#")
  if attr == "" or string.find(attr, "#") ~= 1 then
    return nil
  end
  return attr
end

-- Attempts to find a green color from the current colorscheme
M.find_success_color = function()
  local candidates = {
    "Constant",
    "Keyword",
    "Special",
    "Type",
    "PreProc",
    "Operator",
    "String",
    "Statement",
    "Identifier",
    "Function",
    "Character",
    "Title",
  }
  local best_grp
  local best
  for _, grp in ipairs(candidates) do
    local fg = M.get_group_fg(grp)
    if fg then
      local rgb = hsluv.hex_to_rgb(fg)
      -- Super simple "green" detection heuristic: g - r - b
      local score = rgb[2] - rgb[1] - rgb[3]
      if score > -0.3 then
        if not best or score > best then
          best_grp = grp
          best = score
        end
      end
    end
  end
  if best_grp then
    return best_grp
  end
  return "DiagnosticInfo"
end

return M
