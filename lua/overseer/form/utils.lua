local config = require("overseer.config")
local layout = require("overseer.layout")
local log = require("overseer.log")
local util = require("overseer.util")
local M = {}

---@alias overseer.Param overseer.StringParam|overseer.BoolParam|overseer.NumberParam|overseer.IntParam|overseer.ListParam|overseer.EnumParam|overseer.NamedEnumParam|overseer.OpaqueParam

---@class overseer.BaseParam
---@field name? string
---@field deprecated? boolean
---@field desc? string
---@field long_desc? string
---@field order? integer
---@field validate? fun(value: any): boolean
---@field optional? boolean
---@field default_from_task? boolean

---@class overseer.StringParam : overseer.BaseParam
---@field type? "string"
---@field conceal? boolean
---@field default? string

---@class overseer.BoolParam : overseer.BaseParam
---@field type "boolean"
---@field default? boolean

---@class overseer.NumberParam : overseer.BaseParam
---@field type "number"
---@field default? number

---@class overseer.IntParam : overseer.BaseParam
---@field type "integer"
---@field default? number

---@class overseer.ListParam : overseer.BaseParam
---@field type "list"
---@field subtype? overseer.Param
---@field delimiter? string
---@field default? table

---@class overseer.EnumParam : overseer.BaseParam
---@field type "enum"
---@field default? string
---@field choices string[]

---@class overseer.NamedEnumParam : overseer.BaseParam
---@field type "namedEnum"
---@field default? string
---@field choices? table<string, string>

---@class overseer.OpaqueParam : overseer.BaseParam
---@field type "opaque"
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
  elseif schema.type == "namedEnum" then
    local label
    for k, v in pairs(schema.choices) do
      if v == value then
        label = k
        break
      end
    end
    return label or value
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
  elseif ptype == "namedEnum" then
    return vim.tbl_contains(vim.tbl_values(schema.choices), value)
  elseif ptype == "list" then
    return type(value) == "table" and vim.islist(value)
  elseif ptype == "number" then
    return type(value) == "number"
  elseif ptype == "integer" then
    return type(value) == "number" and math.floor(value) == value
  elseif ptype == "boolean" then
    return type(value) == "boolean"
  elseif ptype == "string" then
    return true
  else
    log.warn("Unknown param type '%s'", ptype)
    return false
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
    ---@diagnostic disable-next-line: param-type-mismatch
    return true, vim.deepcopy(schema.default)
  elseif schema.type == "list" then
    local values = vim.split(value, "%s*" .. schema.delimiter .. "%s*")
    local ret = {}
    for _, v in ipairs(values) do
      -- Skip over empty/whitespace entries. This makes deleting a single entry more graceful
      -- e.g. "FOO, BAR" --(delete)--> "FOO, " ==> should parse the same as "FOO"
      if not v:match("^%s*$") then
        local success, parsed = M.parse_value(schema.subtype, v)
        table.insert(ret, parsed)
        if not success then
          return false, nil
        end
      end
    end
    return true, ret
  elseif schema.type == "enum" then
    local key = value:lower()
    local best
    for _, v in ipairs(schema.choices) do
      if v == value then
        return true, v
      elseif vim.startswith(v:lower(), key) then
        best = v
      end
    end
    return best ~= nil, best
  elseif schema.type == "namedEnum" then
    local key = "^" .. value:lower()
    local best
    ---@cast schema overseer.NamedEnumParam
    for k, v in pairs(schema.choices) do
      if k == value then
        return true, v
      elseif k:lower():match(key) then
        best = v
      end
    end
    return best ~= nil, best
  elseif schema.type == "number" then
    local num = tonumber(value)
    if num then
      return true, num
    end
  elseif schema.type == "integer" then
    local num = tonumber(value)
    if num then
      return true, math.floor(num)
    end
  elseif schema.type == "boolean" then
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

local registered_cmp = false

---@param bufnr integer
---@param opts? { on_resize?: fun(), get_preferred_dim?: fun(): integer, integer }
---@return fun() cleanup
---@return fun() set_layout
M.open_form_win = function(bufnr, opts)
  opts = opts or {}
  vim.validate({
    on_resize = { opts.on_resize, "f", true },
    get_preferred_dim = { opts.get_preferred_dim, "f", true },
  })
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
      zindex = config.form.zindex,
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
  -- Explicitly set these so the "conceal" option will work for string params
  vim.api.nvim_set_option_value("conceallevel", 1, { scope = "local", win = winid })
  vim.api.nvim_set_option_value("concealcursor", "nic", { scope = "local", win = winid })
  for k, v in pairs(config.form.win_opts) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
  end

  local function set_layout()
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_set_config(winid, calc_layout())
    else
      return true
    end
  end

  local winwidth = vim.api.nvim_win_get_width(winid)
  local function on_win_scrolled()
    if not vim.api.nvim_win_is_valid(winid) then
      return true
    end
    local new_width = vim.api.nvim_win_get_width(winid)
    if winwidth ~= new_width then
      winwidth = new_width
      opts.on_resize()
    end
  end

  if opts.on_resize then
    vim.api.nvim_create_autocmd("WinScrolled", {
      desc = "Rerender on window resize",
      pattern = tostring(winid),
      nested = true,
      callback = on_win_scrolled,
    })
  end
  vim.api.nvim_create_autocmd("VimResized", {
    desc = "Rerender on vim resize",
    nested = true,
    callback = set_layout,
  })

  vim.bo[bufnr].omnifunc = "v:lua.overseer_form_omnifunc"
  -- Configure nvim-cmp if installed
  local has_cmp, cmp = pcall(require, "cmp")
  if has_cmp then
    if not registered_cmp then
      require("cmp").register_source("overseer", require("cmp_overseer").new())
      registered_cmp = true
    end
    cmp.setup.buffer({
      enabled = true,
      sources = {
        { name = "overseer" },
        { name = "path" },
      },
    })
  end

  local function cleanup()
    util.leave_insert()
    vim.api.nvim_win_close(winid, true)
  end
  return cleanup, set_layout
end

return M
