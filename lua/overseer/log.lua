local files = require("overseer.files")
local LogHandler = {}

local levels = vim.deepcopy(vim.log.levels)
vim.tbl_add_reverse_lookup(levels)

function LogHandler.new(opts)
  vim.validate({
    type = { opts.type, "s" },
    handle = { opts.handle, "f" },
    formatter = { opts.formatter, "f" },
    level = { opts.level, "n", true },
  })
  return setmetatable({
    type = opts.type,
    handle = opts.handle,
    formatter = opts.formatter,
    level = opts.level or vim.log.levels.INFO,
  }, { __index = LogHandler })
end

function LogHandler:log(level, msg, ...)
  if self.level <= level then
    local text = self.formatter(level, msg, ...)
    self.handle(level, text)
  end
end

local function default_formatter(level, msg, ...)
  local args = vim.F.pack_len(...)
  for i = 1, args.n do
    local v = args[i]
    if type(v) == "table" then
      args[i] = vim.inspect(v)
    elseif v == nil then
      args[i] = "nil"
    end
  end
  local ok, text = pcall(string.format, msg, vim.F.unpack_len(args))
  if ok then
    local str_level = levels[level]
    return string.format("[%s] %s", str_level, text)
  else
    return string.format("[ERROR] error formatting log line: '%s' args %s", msg, vim.inspect(args))
  end
end

local function create_file_handler(opts)
  vim.validate({
    filename = { opts.filename, "s" },
  })
  local ok, stdpath = pcall(vim.fn.stdpath, "log")
  if not ok then
    stdpath = vim.fn.stdpath("cache")
  end
  local filepath = files.join(stdpath, opts.filename)
  local logfile, openerr = io.open(filepath, "a+")
  if not logfile then
    local err_msg = string.format("Failed to open Overseer log file: %s", openerr)
    vim.notify(err_msg, vim.log.levels.ERROR)
    opts.handle = function() end
  else
    opts.handle = function(level, text)
      logfile:write(text)
      logfile:write("\n")
      logfile:flush()
    end
  end
  return LogHandler.new(opts)
end

local function create_notify_handler(opts)
  opts.handle = function(level, text)
    vim.notify(text, level)
  end
  return LogHandler.new(opts)
end

local function create_echo_handler(opts)
  opts.handle = function(level, text)
    local hl = "Normal"
    if level == vim.log.levels.ERROR then
      hl = "DiagnosticError"
    elseif level == vim.log.levels.WARN then
      hl = "DiagnosticWarn"
    end
    vim.api.nvim_echo({ { text, hl } }, true, {})
  end
  return LogHandler.new(opts)
end

local function create_null_handler()
  return LogHandler.new({
    formatter = function() end,
    handle = function() end,
  })
end

local function create_handler(opts)
  vim.validate({
    type = { opts.type, "s" },
  })
  if not opts.formatter then
    opts.formatter = default_formatter
  end
  if opts.type == "file" then
    return create_file_handler(opts)
  elseif opts.type == "notify" then
    return create_notify_handler(opts)
  elseif opts.type == "echo" then
    return create_echo_handler(opts)
  else
    vim.notify(string.format("Unknown log handler %s", opts.type), vim.log.levels.ERROR)
    return create_null_handler()
  end
end

local Log = {}

function Log.new(opts)
  vim.validate({
    handlers = { opts.handlers, "t" },
    level = { opts.level, "n", true },
  })
  local handlers = {}
  for _, defn in ipairs(opts.handlers) do
    table.insert(handlers, create_handler(defn))
  end
  local log = setmetatable({
    handlers = handlers,
  }, { __index = Log })
  if opts.level then
    log:set_level(opts.level)
  end
  return log
end

function Log:set_level(level)
  for _, handler in ipairs(self.handlers) do
    handler.level = level
  end
end

function Log:get_handlers()
  return self.handlers
end

function Log:log(level, msg, ...)
  for _, handler in ipairs(self.handlers) do
    handler:log(level, msg, ...)
  end
end

function Log:trace(...)
  self:log(vim.log.levels.TRACE, ...)
end

function Log:debug(...)
  self:log(vim.log.levels.DEBUG, ...)
end

function Log:info(...)
  self:log(vim.log.levels.INFO, ...)
end

function Log:warn(...)
  self:log(vim.log.levels.WARN, ...)
end

function Log:error(...)
  self:log(vim.log.levels.ERROR, ...)
end

local root = Log.new({
  handlers = {
    {
      type = "echo",
      level = vim.log.levels.WARN,
    },
  },
})

local M = {}

M.new = Log.new

M.set_root = function(logger)
  root = logger
end

M.get_root = function()
  return root
end

setmetatable(M, {
  __index = function(_, key)
    return root[key]
  end,
})

return M
