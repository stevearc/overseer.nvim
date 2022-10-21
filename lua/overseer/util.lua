local M = {}

---@param winid? number
---@return boolean
M.is_floating_win = function(winid)
  ---@diagnostic disable-next-line: undefined-field
  return vim.api.nvim_win_get_config(winid or 0).relative ~= ""
end

---@param bufnr? number
---@return number[] winids
M.get_fixed_wins = function(bufnr)
  local wins = {}
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not M.is_floating_win(winid) and (not bufnr or vim.api.nvim_win_get_buf(winid) == bufnr) then
      table.insert(wins, winid)
    end
  end
  return wins
end

---@return number winid
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

---@param string string
---@param idx number
---@return string
---@return number?
local function get_to_line_end(string, idx)
  local newline = string:find("\n", idx, true)
  local to_end = newline and string:sub(idx, newline - 1) or string:sub(idx)
  return to_end, newline
end

---Splice out an inclusive range from a string
---@param string string
---@param start_idx number
---@param end_idx? number
---@return string
local function str_splice(string, start_idx, end_idx)
  local new_content = string:sub(1, start_idx - 1)
  if end_idx then
    return new_content .. string:sub(end_idx + 1)
  else
    return new_content
  end
end

---@param string string
---@param idx number
---@param needle string
---@return number?
local function str_rfind(string, idx, needle)
  for i = idx, 1, -1 do
    if string:sub(i, i - 1 + needle:len()) == needle then
      return i
    end
  end
end

---Decodes a json string that may contain comments or trailing commas
---@param content string
---@return any
M.decode_json = function(content)
  local ok, data = pcall(vim.json.decode, content, { luanil = { object = true } })
  while not ok do
    local char = data:match("invalid token at character (%d+)$")
    if char then
      local to_end, newline = get_to_line_end(content, char)
      if to_end:match("^//") then
        content = str_splice(content, char, newline)
        goto continue
      end
    end

    char = data:match("Expected object key string but found [^%s]+ at character (%d+)$")
    char = char or data:match("Expected value but found T_ARR_END at character (%d+)")
    if char then
      local comma_idx = str_rfind(content, char, ",")
      if comma_idx then
        content = str_splice(content, comma_idx, comma_idx)
        goto continue
      end
    end

    error(data)
    ::continue::
    ok, data = pcall(vim.json.decode, content, { luanil = { object = true } })
  end
  return data
end

---@param winid number
M.go_win_no_au = function(winid)
  if winid == nil or winid == vim.api.nvim_get_current_win() then
    return
  end
  local winnr = vim.api.nvim_win_get_number(winid)
  vim.cmd(string.format("noau %dwincmd w", winnr))
end

---@param bufnr number
M.go_buf_no_au = function(bufnr)
  vim.cmd(string.format("noau b %d", bufnr))
end

---@param winid? number
M.scroll_to_end = function(winid)
  winid = winid or 0
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local lnum = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(winid, { lnum, 0 })
end

---@param bufnr number
---@param ns number
---@param highlights table
M.add_highlights = function(bufnr, ns, highlights)
  for _, hl in ipairs(highlights) do
    local group, lnum, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(bufnr, ns, group, lnum - 1, col_start, col_end)
  end
end

---@param text string
---@param size number
---@return string
M.ljust = function(text, size)
  local len = vim.api.nvim_strwidth(text)
  if len < size then
    return string.format("%s%s", text, string.rep(" ", size - len))
  end
  return text
end

---@param text string
---@param width number
---@param alignment "left"|"right"|"center"
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

---@return number? winid
M.get_preview_window = function()
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_option(winid, "previewwindow") then
      return winid
    end
  end
end

---@param name_or_config string|table
---@return string
---@return table|nil
M.split_config = function(name_or_config)
  if type(name_or_config) == "string" then
    return name_or_config, nil
  else
    if not name_or_config[1] and name_or_config["1"] then
      -- This was likely loaded from json, so the first element got coerced to a string key
      name_or_config[1] = name_or_config["1"]
      name_or_config["1"] = nil
    end
    return name_or_config[1], name_or_config
  end
end

---@param bufnr? number
---@return boolean
M.is_bufnr_visible = function(bufnr)
  if not bufnr then
    return false
  end
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(winid) == bufnr then
      return true
    end
  end
  return false
end

---@generic T : any
---@param list T[]|string
---@param keyfn? fun(item: T): string
---@return table<T, boolean>
M.list_to_map = function(list, keyfn)
  local map = {}
  if type(list) == "string" then
    map[list] = true
  else
    for _, v in ipairs(list) do
      if keyfn then
        map[keyfn(v)] = true
      else
        map[v] = true
      end
    end
  end
  return map
end

M.leave_insert = function()
  if vim.api.nvim_get_mode().mode:match("^i") then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
  end
end

---Set the appropriate window options for a terminal buffer
M.set_term_window_opts = function(winid)
  winid = winid or 0
  vim.api.nvim_win_set_option(winid, "number", false)
  vim.api.nvim_win_set_option(winid, "relativenumber", false)
  vim.api.nvim_win_set_option(winid, "signcolumn", "no")
end

---@generic T : any
---@param tbl T[]
---@return T[]
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

---@generic T : any
---@param tbl T[]
---@param start_idx? number
---@param end_idx? number
---@return T[]
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

---@generic T : any
---@generic U : any
---@param tbl T[]
---@param needle U
---@param transform? fun(item: T): U
---@return T?
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

---@generic T : any
---@generic U : any
---@param tbl T[]
---@param needle U
---@param extract? fun(item: T): U
---@return number?
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

---@param str string
---@return string
M.remove_ansi = function(str)
  return str
    :gsub("\x1b%[[%d;]*m", "") -- Strip color codes
    :gsub("\x1b%[%d*K", "") -- Strip the "erase in line" codes
end

M.get_stdout_line_iter = function()
  local pending = ""
  return function(data)
    local ret = {}
    for i, chunk in ipairs(data) do
      if i == 1 then
        if chunk == "" then
          table.insert(ret, pending)
          pending = ""
        else
          pending = pending .. string.gsub(M.remove_ansi(chunk), "\r$", "")
        end
      else
        if data[1] ~= "" then
          table.insert(ret, pending)
        end
        pending = string.gsub(M.remove_ansi(chunk), "\r$", "")
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

--- Attempt to detect if a command should be run by the shell (passed as string
--- to termopen)  or if it can be run directly (passed as list to termopen)
---@param cmd string
---@return boolean
M.is_shell_cmd = function(cmd)
  for arg in vim.gsplit(cmd, "%s+") do
    if arg == "|" or arg == "||" or arg == "&&" then
      return true
    end
  end
  return false
end

---@generic T : any
---@param list T[]
---@param cb fun(item: T): boolean
---@return boolean
M.list_any = function(list, cb)
  for _, v in ipairs(list) do
    if cb(v) then
      return true
    end
  end
  return false
end

---@generic T : any
---@param list T[]
---@param cb fun(item: T): boolean
---@return boolean
M.list_all = function(list, cb)
  for _, v in ipairs(list) do
    if not cb(v) then
      return false
    end
  end
  return true
end

---@generic T : any
---@param list T[]
---@param key string
---@return table<string, T>
M.tbl_group_by = function(list, key)
  local ret = {}
  for _, v in ipairs(list) do
    local k = v[key]
    if k then
      if not ret[k] then
        ret[k] = {}
      end
      table.insert(ret[k], v)
    end
  end
  return ret
end

---@generic T : any
---@param list_or_obj T|T[]
---@return fun(): integer, T
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
  local hsluv = require("overseer.hsluv")
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
      if score > -0.5 then
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

---@param func fun(any)
---@param opts? {delay?: integer|fun(any): integer, reset_timer_on_call?: boolean}
M.debounce = function(func, opts)
  vim.validate({
    func = { func, "f" },
    opts = { opts, "t", true },
  })
  opts = opts or {}
  opts.delay = opts.delay or 300
  local timer = nil
  return function(...)
    if timer then
      if opts.reset_timer_on_call then
        timer:close()
        timer = nil
      else
        return timer
      end
    end
    local args = { ... }
    local delay = opts.delay
    if type(delay) == "function" then
      delay = delay(unpack(args))
    end
    timer = vim.loop.new_timer()
    timer:start(delay, 0, function()
      timer:close()
      timer = nil
      vim.schedule_wrap(func)(unpack(args))
    end)
    return timer
  end
end

local minute_s = 60
local hour_s = 60 * minute_s
local day_s = 24 * hour_s
---Format a duration as a human-readable string
---@param duration integer Duration in seconds
---@return string
M.format_duration = function(duration)
  local secs = duration % 60
  local days = math.floor(duration / day_s)
  local hours = math.floor((duration % day_s) / hour_s)
  local mins = math.floor((duration % hour_s) / minute_s)
  local time = ""
  if days > 0 then
    time = string.format("%d day%s ", days, days > 1 and "s" or "")
  end
  if hours > 0 then
    time = string.format("%s%d:", time, hours)
  end
  time = string.format("%s%02d:%02d", time, mins, secs)
  return time
end

M.run_template_or_task = function(name_or_config, cb)
  if type(name_or_config) == "table" and name_or_config[1] == nil then
    -- This is a raw task params table
    cb(require("overseer").new_task(name_or_config))
  else
    local name, dep_params = M.split_config(name_or_config)
    -- If no task ID found, start the dependency
    require("overseer.commands").run_template({
      name = name,
      params = dep_params,
      autostart = false,
    }, cb)
  end
end

return M
