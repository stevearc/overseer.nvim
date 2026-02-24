local M = {}

---@class overseer.ShellEscapeConfig
---@field esc_char? string
---@field strong_esc_char? string string that escapes a strong quote inside a strong quote
---@field special_chars? string
---@field strong string
---@field weak? string

---@type table<string, overseer.ShellEscapeConfig>
local esc_configs = {
  powershell = {
    esc_char = "`",
    strong_esc_char = "'",
    special_chars = "[\"' ()]",
    strong = "'",
    weak = '"',
  },
  cmd = {
    strong = '"',
  },
  bash = {
    esc_char = "\\",
    strong_esc_char = "'\"'\"",
    special_chars = "[\"' ]",
    strong = "'",
    weak = '"',
  },
}

---@param value string
---@param quote string
---@return string
local function wrap(value, quote)
  return quote .. value .. quote
end

---@param value string
---@param config overseer.ShellEscapeConfig
---@return boolean
local function needs_quote(value, config)
  local skip_next = false
  local found_quote
  for c in value:gmatch(".") do
    if skip_next then
      skip_next = false
    elseif c == found_quote then
      -- Matching end quote
      found_quote = nil
    elseif found_quote then
      -- Quoted character; ignore
    elseif c == config.esc_char then
      skip_next = true
    elseif c == config.strong or c == config.weak then
      found_quote = c
    elseif c == " " then
      return true
    end
  end
  return found_quote ~= nil
end

---@param value string
---@param quote string
---@param esc_char nil|string
---@return string
local function escape_quote(value, quote, esc_char)
  if not esc_char then
    return value
  end
  local skip_next = false
  local escaped = value:gsub(".", function(c)
    if skip_next then
      skip_next = false
    elseif c == quote then
      return esc_char .. c
    elseif c == esc_char then
      skip_next = true
    end
    return c
  end)
  return escaped
end

---@param shell nil|string
---@return string
M.normalize_shell_name = function(shell)
  if not shell then
    shell = vim.o.shell
  end
  shell = string.lower(shell)
  local basename = vim.split(vim.fs.basename(shell), ".", { plain = true })[1]
  if basename == "pwsh" then
    return "powershell"
  else
    return basename
  end
end

---@param shell nil|string
---@return overseer.ShellEscapeConfig
local function get_config_for_shell(shell)
  local basename = M.normalize_shell_name(shell)
  if esc_configs[basename] then
    return esc_configs[basename]
  else
    return esc_configs.bash
  end
end

---@param value string
---@param method "escape"|"strong"|"weak" Defaults to "strong"
---@param config overseer.ShellEscapeConfig
---@return string
---@return boolean
local function escape(value, method, config)
  if method == "strong" and config.strong then
    return wrap(escape_quote(value, config.strong, config.strong_esc_char), config.strong), true
  elseif method == "weak" and config.weak then
    return wrap(escape_quote(value, config.weak, config.esc_char), config.weak), true
  elseif method == "escape" and config.esc_char and config.special_chars then
    local escaped, count = value:gsub(config.special_chars, function(char)
      return config.esc_char .. char
    end)
    return escaped, count > 0
  end
  return value, false
end

---Escapes an argument for use in the shell
---@param value string
---@param method nil|"escape"|"strong"|"weak" Defaults to "strong"
---@param shell nil|string Defaults to vim.o.shell
---@return string
---@return boolean
---@note
--- escape/strong/weak behavior copied from
--- https://code.visualstudio.com/Docs/editor/tasks#_custom-tasks
M.escape = function(value, method, shell)
  if not method then
    method = "strong"
  end
  local config = get_config_for_shell(shell)

  return escape(value, method, config)
end

---Escapes an argument for use in the shell if necessary
---@param value string
---@param method nil|"escape"|"strong"|"weak" Defaults to "strong"
---@param shell nil|string Defaults to vim.o.shell
---@return string
---@return boolean
---@note
--- escape/strong/weak behavior copied from
--- https://code.visualstudio.com/Docs/editor/tasks#_custom-tasks
M.escape_if_needed = function(value, method, shell)
  if not method then
    method = "strong"
  end
  local config = get_config_for_shell(shell)
  if needs_quote(value, config) then
    return escape(value, method, config)
  else
    return value, false
  end
end

---Escapes a command for use in the shell
---@param cmd string[]
---@param method nil|"escape"|"strong"|"weak" Defaults to "strong"
---@param shell nil|string Defaults to vim.o.shell
---@return string
---@return boolean
---@note
--- escape/strong/weak behavior copied from
--- https://code.visualstudio.com/Docs/editor/tasks#_custom-tasks
M.escape_cmd = function(cmd, method, shell)
  if not method then
    method = "strong"
  end
  local config = get_config_for_shell(shell)

  local pieces = {}
  local args_quoted = false
  for i, v in ipairs(cmd) do
    local arg_quote_method
    if type(v) == "table" then
      arg_quote_method = v.quoting
      v = v.value
    end
    if i ~= 1 and needs_quote(v, config) then
      args_quoted = true
      local escaped = escape(v, arg_quote_method or method, config)
      table.insert(pieces, escaped)
    else
      table.insert(pieces, v)
    end
  end

  local str_cmd = table.concat(pieces, " ")
  local norm_shell = M.normalize_shell_name(shell)
  if norm_shell == "powershell" then
    str_cmd = "& " .. str_cmd
  elseif norm_shell == "cmd" and args_quoted then
    str_cmd = wrap(str_cmd, '"')
  end
  return str_cmd, args_quoted
end

return M
