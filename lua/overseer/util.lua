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
  if vim.bo.buftype == "" then
    return vim.api.nvim_get_current_win()
  end
  for _, winid in ipairs(M.get_fixed_wins()) do
    local bufnr = vim.api.nvim_win_get_buf(winid)
    if vim.bo[bufnr].buftype == "" then
      return winid
    end
  end
  return 0
end

M.decode_json = function(...)
  return require("overseer.json").decode(...)
end

---@param winid number
M.go_win_no_au = function(winid)
  if winid == nil or winid == vim.api.nvim_get_current_win() then
    return
  end
  local winnr = vim.api.nvim_win_get_number(winid)
  vim.cmd.wincmd({ args = { "w" }, count = winnr, mods = { noautocmd = true } })
end

---@param bufnr number
M.go_buf_no_au = function(bufnr)
  vim.cmd.buffer({ count = bufnr, mods = { noautocmd = true } })
end

local function term_get_effective_line_count(bufnr)
  local linecount = vim.api.nvim_buf_line_count(bufnr)

  local non_blank_lines = linecount
  for i = linecount, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, true)[1]
    non_blank_lines = i
    if line ~= "" then
      break
    end
  end
  return non_blank_lines
end

local _cursor_moved_autocmd
local function create_cursormoved_tail_autocmd()
  if _cursor_moved_autocmd then
    return
  end
  _cursor_moved_autocmd = vim.api.nvim_create_autocmd("CursorMoved", {
    callback = function(args)
      if vim.bo[args.buf].buftype ~= "terminal" or args.buf ~= vim.api.nvim_get_current_buf() then
        return
      end
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      local linecount = vim.api.nvim_buf_line_count(0)
      if lnum == linecount then
        vim.w.overseer_pause_tail_for_buf = nil
      else
        vim.w.overseer_pause_tail_for_buf = args.buf
      end
    end,
  })
end

---@param bufnr nil|integer
M.terminal_tail_hack = function(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local winids = M.buf_list_wins(bufnr)
  if vim.tbl_isempty(winids) then
    return
  end
  create_cursormoved_tail_autocmd()
  local linecount = vim.api.nvim_buf_line_count(bufnr)

  local non_blank_lines = term_get_effective_line_count(bufnr)

  local overflow = 6
  local editor_height = vim.o.lines
  local current_win = vim.api.nvim_get_current_win()
  for _, winid in ipairs(winids) do
    local scroll_to_line
    if winid ~= current_win and vim.w[winid].overseer_pause_tail_for_buf ~= bufnr then
      local lnum = vim.api.nvim_win_get_cursor(winid)[1]
      local cursor_at_top = lnum < editor_height
      local not_much_output = linecount < editor_height + overflow
      local num_blank = linecount - non_blank_lines
      if num_blank < 4 then
        scroll_to_line = linecount
      elseif cursor_at_top and not_much_output then
        scroll_to_line = non_blank_lines
      end
    end

    if scroll_to_line then
      local last_line =
        vim.api.nvim_buf_get_lines(bufnr, scroll_to_line - 1, scroll_to_line, true)[1]
      local scrolloff = vim.api.nvim_get_option_value("scrolloff", { scope = "local", win = winid })
      vim.api.nvim_set_option_value("scrolloff", 0, { scope = "local", win = winid })
      vim.api.nvim_win_set_cursor(winid, { scroll_to_line, vim.api.nvim_strwidth(last_line) })
      vim.api.nvim_set_option_value("scrolloff", scrolloff, { scope = "local", win = winid })
    end
  end
end

---@param winid? number
M.scroll_to_end = function(winid)
  winid = winid or 0
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local lnum = vim.api.nvim_buf_line_count(bufnr)
  local last_line = vim.api.nvim_buf_get_lines(bufnr, -2, -1, true)[1]
  -- Hack: terminal buffers add a bunch of empty lines at the end. We need to ignore them so that
  -- we don't end up scrolling off the end of the useful output.
  local not_much_output = lnum < vim.o.lines + 6
  if vim.bo[bufnr].buftype == "terminal" and not_much_output then
    lnum = term_get_effective_line_count(bufnr)
    last_line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
  end
  local scrolloff = vim.api.nvim_get_option_value("scrolloff", { scope = "local", win = winid })
  vim.api.nvim_set_option_value("scrolloff", 0, { scope = "local", win = winid })
  vim.api.nvim_win_set_cursor(winid, { lnum, vim.api.nvim_strwidth(last_line) })
  vim.api.nvim_set_option_value("scrolloff", scrolloff, { scope = "local", win = winid })
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
    if vim.wo[winid].previewwindow then
      return winid
    end
  end
end

---@param bufnr integer
---@return integer[]
M.buf_list_wins = function(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local ret = {}
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      table.insert(ret, winid)
    end
  end
  return ret
end

---@param name_or_config overseer.Serialized
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
  vim.api.nvim_set_option_value("number", false, { scope = "local", win = winid })
  vim.api.nvim_set_option_value("relativenumber", false, { scope = "local", win = winid })
  vim.api.nvim_set_option_value("signcolumn", "no", { scope = "local", win = winid })
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

---Removes some ansi escape codes from a string
---@param str string
---@return string
M.remove_ansi = function(str)
  local ret = str
    :gsub("\x1b%[[%d;]*m", "") -- Strip color codes
    :gsub("\x1b%[%d*K", "") -- Strip the "erase in line" codes
  return ret
end

---Removes carriage returns and some ansi escape codes from a string
---@param str string
---@return string
M.clean_job_line = function(str)
  return M.remove_ansi(str:gsub("\r$", ""))
end

---@return fun(data: string[]): string[]
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
          pending = pending .. M.clean_job_line(chunk)
        end
      else
        if not (data[1] == "" and i == 2) then
          table.insert(ret, pending)
        end
        pending = M.clean_job_line(chunk)
      end
    end
    return ret
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
    ---@diagnostic disable-next-line: redundant-return-value
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

---@param group string
---@return nil|integer
M.get_hl_foreground = function(group)
  if vim.fn.has("nvim-0.9") == 1 then
    return vim.api.nvim_get_hl(0, { name = group }).fg
  else
    return vim.api.nvim_get_hl_by_name(group, true).foreground
  end
end

---@param color integer
---@return number[]
M.color_to_rgb = function(color)
  local r = bit.band(bit.rshift(color, 16), 0xff)
  local g = bit.band(bit.rshift(color, 8), 0xff)
  local b = bit.band(color, 0xff)
  return { r / 255.0, g / 255.0, b / 255.0 }
end

-- Attempts to find a green color from the current colorscheme
M.find_success_color = function()
  if vim.fn.has("nvim-0.9") == 1 then
    return "DiagnosticOk"
  end
  local candidates = {
    "DiagnosticOk",
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
    local fg = M.get_hl_foreground(grp)
    if fg then
      local rgb = M.color_to_rgb(fg)
      -- Super simple "green" detection heuristic: g - r - b
      local score = rgb[2] - rgb[1] - rgb[3]
      if not best or score > best then
        best_grp = grp
        best = score
      end
    end
  end
  if best_grp and best > -0.5 then
    return best_grp
  end
  return "DiagnosticInfo"
end

---@param func fun(...: any)
---@param opts? {reset_timer_on_call: nil|boolean, delay: nil|integer|fun(...: any): integer}
M.debounce = function(func, opts)
  vim.validate({
    func = { func, "f" },
    opts = { opts, "t", true },
  })
  opts = opts or {}
  local delay = opts.delay or 300
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
    if type(delay) == "function" then
      delay = delay(unpack(args))
    end
    timer = assert(vim.loop.new_timer())
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

---Run a function in the context of a full-editor window
---@param bufnr nil|integer
---@param callback fun()
M.run_in_fullscreen_win = function(bufnr, callback)
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  end
  local winid = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    noautocmd = true,
  })
  local winnr = vim.api.nvim_win_get_number(winid)
  vim.cmd.wincmd({ count = winnr, args = { "w" }, mods = { noautocmd = true } })
  callback()
  vim.cmd.close({ count = winnr, mods = { noautocmd = true, emsg_silent = true } })
end

---Run a function in the context of a current directory
---@param cwd string
---@param callback fun()
M.run_in_cwd = function(cwd, callback)
  M.run_in_fullscreen_win(nil, function()
    vim.cmd.lcd({ args = { cwd }, mods = { noautocmd = true } })
    callback()
  end)
end

---@param status overseer.Status
---@return integer
M.status_to_log_level = function(status)
  local constants = require("overseer.constants")
  local STATUS = constants.STATUS
  if status == STATUS.FAILURE then
    return vim.log.levels.ERROR
  elseif status == STATUS.CANCELED then
    return vim.log.levels.WARN
  else
    return vim.log.levels.INFO
  end
end

---Delete buffer. If buffer is visible, set bufhidden=wipe instead
---@param bufnr integer
M.soft_delete_buf = function(bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    if M.is_bufnr_visible(bufnr) then
      vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    else
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

---This is a hack so we don't end up in insert mode after starting a task
---@param prev_mode string The vim mode we were in before opening a terminal
M.hack_around_termopen_autocmd = function(prev_mode)
  -- It's common to have autocmds that enter insert mode when opening a terminal
  vim.defer_fn(function()
    local new_mode = vim.api.nvim_get_mode().mode
    if new_mode ~= prev_mode then
      if string.find(new_mode, "i") == 1 then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
        if string.find(prev_mode, "v") == 1 or string.find(prev_mode, "V") == 1 then
          vim.cmd.normal({ bang = true, args = { "gv" } })
        end
      end
    end
  end, 10)
end

---@param old_bufnr nil|integer
---@param new_bufnr nil|integer
M.replace_buffer_in_wins = function(old_bufnr, new_bufnr)
  if not old_bufnr or not new_bufnr then
    return
  end
  local has_stickybuf, stickybuf = pcall(require, "stickybuf")
  -- If this task's previous buffer was open in any wins, replace it
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == old_bufnr then
      -- If stickybuf is installed, make sure it doesn't interfere
      if has_stickybuf then
        stickybuf.unpin(win)
      end
      vim.api.nvim_win_set_buf(win, new_bufnr)
    end
  end
end

return M
