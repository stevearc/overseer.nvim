local config = require("overseer.config")
local util = require("overseer.util")
local M = {}

M.render_field = function(schema, prefix, name, value)
  if value == nil then
    value = ""
  end
  if type(value) == "table" then
    value = table.concat(value, " ")
  end

  return string.format("%s%s: %s", prefix, name, value)
end

M.validate_field = function(schema, value)
  local ptype = schema.type or "string"
  if value == nil then
    return schema.optional
  elseif ptype == "list" then
    return type(value) == "table" and vim.tbl_islist(value)
  elseif ptype == "number" then
    return type(value) == "number"
  elseif ptype == "bool" then
    return type(value) == "boolean"
  elseif ptype == "string" then
    return true
  else
    vim.notify(string.format("Unknown param type '%s'", ptype), vim.log.levels.WARN)
  end
end

M.parse_field = function(schema, prefix, name, line)
  local label = string.format("%s%s: ", prefix, name)
  if string.sub(line, 1, string.len(label)) ~= label then
    return false
  end
  local value = string.sub(line, string.len(label) + 1)
  return M.parse_value(schema, value)
end

M.parse_value = function(schema, value)
  if value == "" then
    return true, nil
  end
  if schema.type == "list" then
    -- TODO escaping? configurable delimiter? quoting?
    return true, vim.split(value, "%s+")
  elseif schema.type == "number" then
    local num = tonumber(value)
    -- If the number ends with '.' or '.0' don't parse it yet, because that will
    -- truncate it and cause problems for input.
    if num and not string.match(value, "%.$") and not string.match(value, "%.%d*0+$") then
      return true, num
    end
  elseif schema.type == "bool" then
    if string.match(value, "^ye?s?") or string.match(value, "^tr?u?e?") then
      return true, true
    elseif string.match(value, "^no?") or string.match(value, "^fa?l?s?e?") then
      return true, false
    end
  end
  return true, value
end

local function is_float(value)
  local _, p = math.modf(value)
  return p ~= 0
end

local function calc_float(value, max_value)
  if value and is_float(value) then
    return math.min(max_value, value * max_value)
  else
    return value
  end
end

M.get_editor_width = function()
  return vim.o.columns
end

M.get_editor_height = function()
  return vim.o.lines - vim.o.cmdheight
end

local function calc_list(values, max_value, aggregator, limit)
  local ret = limit
  if type(values) == "table" then
    for _, v in ipairs(values) do
      ret = aggregator(ret, calc_float(v, max_value))
    end
    return ret
  else
    ret = aggregator(ret, calc_float(values, max_value))
  end
  return ret
end

local function calculate_dim(desired_size, exact_size, min_size, max_size, total_size)
  local ret = calc_float(exact_size, total_size)
  local min_val = calc_list(min_size, total_size, math.max, 1)
  local max_val = calc_list(max_size, total_size, math.min, total_size)
  if not ret then
    if not desired_size then
      ret = (min_val + max_val) / 2
    else
      ret = calc_float(desired_size, total_size)
    end
  end
  ret = math.min(ret, max_val)
  ret = math.max(ret, min_val)
  return math.floor(ret)
end

M.open_form_win = function(bufnr, opts)
  opts = opts or {}
  vim.validate({
    autocmds = { opts.autocmds, "t", true },
    on_resize = { opts.on_resize, "f", true },
    get_preferred_dim = { opts.get_preferred_dim, "f", true },
  })
  opts.autocmds = opts.autocmds or {}
  local function calc_layout()
    local desired_width
    local desired_height
    if opts.get_preferred_dim then
      desired_width, desired_height = opts.get_preferred_dim()
    end
    local width = calculate_dim(
      desired_width,
      config.form.width,
      config.form.min_width,
      config.form.max_width,
      M.get_editor_width()
    )
    local height = calculate_dim(
      desired_height,
      config.form.height,
      config.form.min_height,
      config.form.max_height,
      M.get_editor_height()
    )
    local win_opts = {
      relative = "editor",
      border = config.form.border,
      zindex = 40,
      width = width,
      height = height,
    }
    win_opts.col = math.floor((M.get_editor_width() - width) / 2)
    win_opts.row = math.floor((M.get_editor_height() - height) / 2)
    return win_opts
  end

  local winopt = calc_layout()
  winopt.style = "minimal"
  local winid = vim.api.nvim_open_win(bufnr, true, winopt)
  vim.api.nvim_win_set_option(winid, "winblend", config.form.winblend)

  local function layout()
    vim.api.nvim_win_set_config(winid, calc_layout())
  end

  local winwidth = vim.api.nvim_win_get_width(winid)
  local function on_win_scrolled()
    local new_width = vim.api.nvim_win_get_width(winid)
    if winwidth ~= new_width then
      winwidth = new_width
      opts.on_resize()
    end
  end

  if opts.on_resize then
    table.insert(
      opts.autocmds,
      vim.api.nvim_create_autocmd("WinScrolled", {
        desc = "Rerender on window resize",
        pattern = tostring(winid),
        nested = true,
        callback = on_win_scrolled,
      })
    )
  end
  table.insert(
    opts.autocmds,
    vim.api.nvim_create_autocmd("VimResized", {
      desc = "Rerender on vim resize",
      nested = true,
      callback = layout,
    })
  )
  -- This is a little bit of a hack. We force the cursor to be *after the ': '
  -- of the fields, but if the user enters insert mode with "i", the cursor will
  -- now be before the space. If they type, the parsing will misbehave. So we
  -- detect that and just...nudge them forwards a bit.
  table.insert(
    opts.autocmds,
    vim.api.nvim_create_autocmd("InsertCharPre", {
      desc = "Move cursor to end of line when inserting",
      buffer = bufnr,
      nested = true,
      callback = function()
        local cur = vim.api.nvim_win_get_cursor(0)
        local lnum = cur[1]
        local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
        local name = line:match("^[^%s]+: ")
        if cur[2] < string.len(name) then
          vim.api.nvim_win_set_cursor(0, { lnum, string.len(name) })
        end
      end,
    })
  )

  local function cleanup()
    for _, id in ipairs(opts.autocmds) do
      vim.api.nvim_del_autocmd(id)
    end
    util.leave_insert()
    vim.api.nvim_win_close(winid, true)
  end
  return cleanup, layout
end

return M
