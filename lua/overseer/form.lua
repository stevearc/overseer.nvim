local config = require("overseer.config")
local layout = require("overseer.layout")
local log = require("overseer.log")
local util = require("overseer.util")
local M = {}

---@alias overseer.Param overseer.StringParam|overseer.BoolParam|overseer.NumberParam|overseer.IntParam|overseer.ListParam|overseer.EnumParam|overseer.OpaqueParam

---@class overseer.StringParam
---@field name? string
---@field desc? string
---@field validate? fun(value: any): boolean
---@field optional? boolean
---@field type? "string"
---@field default? string

---@class overseer.BoolParam
---@field name? string
---@field desc? string
---@field validate? fun(value: any): boolean
---@field optional? boolean
---@field type "bool"
---@field default? boolean

---@class overseer.NumberParam
---@field name? string
---@field desc? string
---@field validate? fun(value: any): boolean
---@field optional? boolean
---@field type "number"
---@field default? number

---@class overseer.IntParam
---@field name? string
---@field desc? string
---@field validate? fun(value: any): boolean
---@field optional? boolean
---@field type? "int"
---@field default? number

---@class overseer.ListParam
---@field name? string
---@field desc? string
---@field validate? fun(value: any): boolean
---@field optional? boolean
---@field type? "list"
---@field subtype? overseer.Param
---@field delimiter? string
---@field default? table

---@class overseer.EnumParam
---@field name? string
---@field desc? string
---@field validate? fun(value: any): boolean
---@field optional? boolean
---@field type? "enum"
---@field default? string
---@field choices string[]

---@class overseer.OpaqueParam
---@field name? string
---@field desc? string
---@field validate? fun(value: any): boolean
---@field optional? boolean
---@field type? "opaque"
---@field default? any

local default_schema = {
  list = {
    delimiter = ", ",
    subtype = { type = "string" },
  },
}

---@param params overseer.Params
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
      desc = { param.desc, "s", true },
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

---@param schema overseer.Param
---@value any
---@return string
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

---@param schema overseer.Param
---@param prefix string
---@param name string
---@param value any
---@return string
M.render_field = function(schema, prefix, name, value)
  local str_value = M.render_value(schema, value)
  return string.format("%s%s: %s", prefix, name, str_value)
end

---@param schema overseer.Param
---@param value any
---@return boolean
local function validate_type(schema, value)
  local ptype = schema.type or "string"
  if value == nil then
    return schema.optional
  elseif ptype == "opaque" then
    return true
  elseif ptype == "enum" then
    return vim.tbl_contains(schema.choices, value)
  elseif ptype == "list" then
    return type(value) == "table" and vim.tbl_islist(value)
  elseif ptype == "number" then
    return type(value) == "number"
  elseif ptype == "int" then
    return type(value) == "number" and math.floor(value) == value
  elseif ptype == "bool" then
    return type(value) == "boolean"
  elseif ptype == "string" then
    return true
  else
    log:warn("Unknown param type '%s'", ptype)
  end
end

---@param schema overseer.Param
---@param value any
---@return boolean
M.validate_field = function(schema, value)
  if not validate_type(schema, value) then
    return false
  end
  if schema.validate and value ~= nil then
    return schema.validate(value)
  end
  return true
end

---@param schema overseer.Param
---@param prefix string
---@param name string
---@param line string
---@return boolean success
---@return any? parsed_value
M.parse_field = function(schema, prefix, name, line)
  local label = string.format("%s%s: ", prefix, name)
  if string.sub(line, 1, string.len(label)) ~= label then
    return false
  end
  local value = string.sub(line, string.len(label) + 1)
  return M.parse_value(schema, value)
end

---@param schema overseer.Param
---@param value string
---@return boolean success
---@return any? parsed_value
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
  elseif schema.type == "enum" then
    local key = "^" .. value:lower()
    local best
    for _, v in ipairs(schema.choices) do
      if v == value then
        return true, v
      elseif v:lower():match(key) then
        best = v
      end
    end
    return best ~= nil, best
  elseif schema.type == "number" then
    local num = tonumber(value)
    if num then
      return true, num
    end
  elseif schema.type == "int" then
    local num = tonumber(value)
    if num then
      return true, math.floor(num)
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

---@param findstart number
---@param base string
---@return number|string[]
function _G.overseer_form_omnifunc(findstart, base)
  if findstart == 1 then
    return vim.api.nvim_win_get_cursor(0)[2]
  else
    local ok, choices = pcall(vim.api.nvim_buf_get_var, 0, "overseer_choices")
    return ok and choices or {}
  end
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

  vim.api.nvim_buf_set_option(0, "omnifunc", "v:lua.overseer_form_omnifunc")
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
