local config = require("overseer.config")
local layout = require("overseer.layout")
local log = require("overseer.log")
local util = require("overseer.util")
local M = {}

local default_schema = {
  list = {
    delimiter = ", ",
    subtype = { type = "string" },
  },
}

M.validate_params = function(params)
  for name, param in pairs(params) do
    if not param.type then
      param.type = "string"
    end
    if name:match("%s") then
      error(string.format("Param '%s' cannot contain whitespace", name))
    end
    vim.validate({
      name = { param.name, "s", true },
      description = { param.description, "s", true },
      optional = { param.optional, "b", true },
      -- default = any type
    })
    local default = default_schema[param.type]
    if default then
      for k, v in pairs(default) do
        if not param[k] then
          param[k] = v
        end
      end
    end
  end
end

M.render_value = function(schema, value)
  if value == nil then
    return ""
  end
  if schema.type == "opaque" then
    return "<opaque>"
  elseif type(value) == "table" then
    local rendered_values = {}
    for _, v in ipairs(value) do
      table.insert(rendered_values, M.render_value(schema.subtype or {}, v))
    end
    return table.concat(rendered_values, schema.delimiter or ", ")
  end
  return value
end

M.render_field = function(schema, prefix, name, value)
  local str_value = M.render_value(schema, value)
  return string.format("%s%s: %s", prefix, name, str_value)
end

M.validate_field = function(schema, value)
  local ptype = schema.type or "string"
  if value == nil then
    return schema.optional
  elseif ptype == "opaque" then
    return true
  elseif ptype == "list" then
    return type(value) == "table" and vim.tbl_islist(value)
  elseif ptype == "number" then
    return type(value) == "number"
  elseif ptype == "bool" then
    return type(value) == "boolean"
  elseif ptype == "string" then
    return true
  else
    log:warn("Unknown param type '%s'", ptype)
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
  if schema.type == "opaque" then
    return false
  elseif value == "" then
    return true, nil
  elseif schema.type == "list" then
    local values = vim.split(value, "%s*" .. schema.delimiter .. "%s*")
    local success
    for i, v in ipairs(values) do
      success, values[i] = M.parse_value(schema.subtype, v)
      if not success then
        return false, nil
      end
    end
    return true, values
  elseif schema.type == "number" then
    local num = tonumber(value)
    if num then
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
    local width = layout.calculate_width(desired_width, config.form)
    local height = layout.calculate_height(desired_height, config.form)
    local win_opts = {
      relative = "editor",
      border = config.form.border,
      zindex = 40,
      width = width,
      height = height,
      col = math.floor((layout.get_editor_width() - width) / 2),
      row = math.floor((layout.get_editor_height() - height) / 2),
    }
    return win_opts
  end

  local winopt = calc_layout()
  winopt.style = "minimal"
  local winid = vim.api.nvim_open_win(bufnr, true, winopt)
  vim.api.nvim_win_set_option(winid, "winblend", config.form.winblend)

  local function set_layout()
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
      callback = set_layout,
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
        if name and cur[2] < string.len(name) then
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
  return cleanup, set_layout
end

return M
