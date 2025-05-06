local log = require("overseer.log")
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

---@param bufnr integer
---@param ns integer
---@param lines overseer.TextChunk[][]
M.render_buf_chunks = function(bufnr, ns, lines)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local new_lines = {}
  local extmarks = {}
  for _, chunks in ipairs(lines) do
    local line = {}
    local i = 0
    for _, chunk in ipairs(chunks) do
      ---@cast chunk overseer.TextChunk
      local text, hl = chunk[1], chunk[2]
      assert(type(text) == "string", "Text chunk must have a string as the first element")
      table.insert(line, text)
      if hl then
        table.insert(extmarks, { #new_lines, i, { hl_group = hl, end_col = i + #text } })
      end
      i = i + #text
    end
    local line_text = table.concat(line, ""):gsub("\n", " ")
    table.insert(new_lines, line_text)
  end
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  for _, extmark in ipairs(extmarks) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, extmark[1], extmark[2], extmark[3])
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
---@return string
M.align = function(text, width, alignment)
  local textwidth = vim.api.nvim_strwidth(text)
  if alignment == "center" then
    local padding = math.floor((width - textwidth) / 2)
    return string.rep(" ", padding) .. text .. string.rep(" ", width - textwidth - padding)
  elseif alignment == "right" then
    local padding = width - textwidth
    return string.rep(" ", padding) .. text
  else
    local padding = width - textwidth
    return text .. string.rep(" ", padding)
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

---@param func fun(...: any)
---@param opts? {reset_timer_on_call: nil|boolean, delay: nil|integer|fun(...: any): integer}
M.debounce = function(func, opts)
  vim.validate("func", func, "function")
  vim.validate("opts", opts, "table", true)
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
    timer = assert(vim.uv.new_timer())
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

---@param time integer
---@return string
M.format_relative_timestamp = function(time)
  local from_now = time - os.time()
  local suffix = ""
  if from_now <= 0 and from_now > -5 then
    return "just now"
  elseif from_now > 0 and from_now <= 5 then
    return "a few seconds"
  end
  if from_now < 0 then
    from_now = -from_now
    suffix = " ago"
  end
  local secs = from_now % 60
  local days = math.floor(from_now / day_s)
  local hours = math.floor((from_now % day_s) / hour_s)
  local mins = math.floor((from_now % hour_s) / minute_s)
  if days > 0 then
    return string.format("%d day%s%s", days, days > 1 and "s" or "", suffix)
  elseif hours > 0 then
    return string.format("%d hour%s%s", hours, hours > 1 and "s" or "", suffix)
  elseif mins > 0 then
    return string.format("%d minute%s%s", mins, mins > 1 and "s" or "", suffix)
  else
    return string.format("%d second%s%s", secs, secs > 1 and "s" or "", suffix)
  end
end

---@param name_or_config string|table
---@param cb fun(task: nil|overseer.Task)
M.run_template_or_task = function(name_or_config, cb)
  if type(name_or_config) == "table" and name_or_config[1] == nil then
    -- This is a raw task params table
    ---@cast name_or_config overseer.TaskDefinition
    cb(require("overseer").new_task(name_or_config))
  else
    local name, dep_params = M.split_config(name_or_config)
    -- If no task ID found, start the dependency
    require("overseer").run_task({
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
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].bufhidden = "wipe"
  end
  local start_winid = vim.api.nvim_get_current_win()
  local eventignore = vim.o.eventignore
  vim.o.eventignore = "all"
  local winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
  })
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then
    vim.api.nvim_echo({ { err } }, true, { err = true })
  end
  pcall(vim.api.nvim_win_close, winid, true)
  vim.api.nvim_set_current_win(start_winid)
  vim.o.eventignore = eventignore
end

---Run a function in the context of a current directory
---@param cwd? string
---@param callback fun()
M.run_in_cwd = function(cwd, callback)
  if not cwd then
    return callback()
  end
  local prev_cwd = vim.fn.getcwd()
  vim.cmd.lcd({ args = { cwd }, mods = { emsg_silent = true, noautocmd = true } })
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then
    vim.api.nvim_echo({ { err } }, true, { err = true })
  end
  vim.cmd.lcd({ args = { prev_cwd }, mods = { emsg_silent = true, noautocmd = true } })
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
      vim.bo[bufnr].bufhidden = "wipe"
    else
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
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

--- Get last N non-empty lines of job output
---@param bufnr integer
---@param num_lines integer
---@return string[]
M.get_last_output_lines = function(bufnr, num_lines)
  local end_line = vim.api.nvim_buf_line_count(bufnr)
  num_lines = math.min(num_lines, end_line)
  local lines = {}
  while end_line > 0 and #lines < num_lines do
    local need_lines = num_lines - #lines
    lines = vim.list_extend(
      vim.api.nvim_buf_get_lines(bufnr, math.max(0, end_line - need_lines), end_line, false),
      lines
    )
    while
      not vim.tbl_isempty(lines)
      and (lines[#lines]:match("^%s*$") or lines[#lines]:match("^%[Process exited"))
    do
      table.remove(lines)
    end
    end_line = end_line - need_lines
  end
  return lines
end

---@class overseer.Caller
---@field file? string
---@field lnum? integer
---@field module? string
---@field top_module? string

---@param file string
---@param caller overseer.Caller
local function assign_module(file, caller)
  local relpath
  for path in vim.gsplit(vim.o.runtimepath, ",", { plain = true }) do
    path = path .. "/lua"
    if file:find(path, 1, true) == 1 then
      relpath = file:sub(#path + 2)
      break
    end
  end
  if relpath then
    local mod = vim.fn.fnamemodify(relpath, ":r"):gsub("[/\\]", ".")
    local top_mod
    local dot_idx = mod:find(".", 1, true)
    if dot_idx then
      top_mod = mod:sub(1, dot_idx - 1)
    else
      top_mod = mod
    end
    caller.module = mod
    caller.top_module = top_mod
  end
end

---@return overseer.Caller
M.get_caller = function()
  -- 1: this function
  -- 2: the wrapper function in init.lua
  -- 3: the actual caller of the jobstart/system function
  local level = 3
  local info
  while true do
    info = debug.getinfo(level, "Sl")
    if not info then
      log.trace("No source info found: %s", debug.traceback())
      return {}
    end
    if info.what ~= "C" then
      break
    end
    level = level + 1
  end
  local file, lnum
  if not info.source:match("^@") then
    log.trace("Source is not file: %s\n%s", info.source, debug.traceback())
    return {}
  end

  file = info.source:sub(2)
  lnum = info.currentline
  local ret = { file = file, lnum = lnum }
  if vim.in_fast_event() then
    -- This reads runtimepath and uses fnamemodify, which are not safe in fast events
    vim.schedule_wrap(assign_module)(file, ret)
  else
    assign_module(file, ret)
  end
  return ret
end

return M
