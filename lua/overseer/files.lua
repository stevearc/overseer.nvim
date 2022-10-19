local util = require("overseer.util")
local M = {}

---@type boolean
M.is_windows = vim.loop.os_uname().version:match("Windows")

---@type boolean
M.is_mac = vim.loop.os_uname().sysname == "Darwin"

---@type string
M.sep = M.is_windows and "\\" or "/"

---@param ... string
---@return boolean
M.any_exists = function(...)
  for _, name in ipairs({ ... }) do
    if M.exists(name) then
      return true
    end
  end
  return false
end

---@param filepath string
---@return boolean
M.exists = function(filepath)
  local stat = vim.loop.fs_stat(filepath)
  return stat ~= nil and stat.type ~= nil
end

---@return string
M.join = function(...)
  return table.concat({ ... }, M.sep)
end

M.is_absolute = function(path)
  if M.is_windows then
    return path:lower():match("^%w:")
  else
    return vim.startswith(path, "/")
  end
end

M.abspath = function(path)
  if not M.is_absolute(path) then
    path = vim.fn.fnamemodify(path, ":p")
  end
  return path
end

---@param root string
---@param candidate string
---@return boolean
M.is_subpath = function(root, candidate)
  if candidate == "" then
    return false
  end
  root = M.abspath(root)
  candidate = M.abspath(candidate)
  return candidate:sub(1, root:len()) == root
end

M.get_stdpath_filename = function(stdpath, ...)
  local ok, dir = pcall(vim.fn.stdpath, stdpath)
  if not ok then
    if stdpath == "log" then
      return M.get_stdpath_filename("cache", ...)
    elseif stdpath == "state" then
      return M.get_stdpath_filename("data", ...)
    else
      error(dir)
    end
  end
  return M.join(dir, ...)
end

---@param filepath string
---@return string?
M.read_file = function(filepath)
  if not M.exists(filepath) then
    return nil
  end
  local fd = vim.loop.fs_open(filepath, "r", 420) -- 0644
  local stat = vim.loop.fs_fstat(fd)
  local content = vim.loop.fs_read(fd, stat.size)
  vim.loop.fs_close(fd)
  return content
end

---@param data_dir "cache"|"config"|"data"|"log"
---@param basename string
---@return string
M.gen_random_filename = function(data_dir, basename)
  local num = 0
  for _ = 1, 5 do
    num = 10 * num + math.random(0, 9)
  end
  return M.get_stdpath_filename(data_dir, "overseer", basename:format(num))
end

---@param filepath string
---@return any?
M.load_json_file = function(filepath)
  local content = M.read_file(filepath)
  if content then
    return util.decode_json(content)
  end
end

---@param dir string
---@return string[]
M.list_files = function(dir)
  local fd = vim.loop.fs_opendir(dir, nil, 32)
  local entries = vim.loop.fs_readdir(fd)
  local ret = {}
  while entries do
    for _, entry in ipairs(entries) do
      if entry.type == "file" then
        table.insert(ret, entry.name)
      end
    end
    entries = vim.loop.fs_readdir(fd)
  end
  vim.loop.fs_closedir(fd)
  return ret
end

---@param dirname string
---@param perms? number
M.mkdir = function(dirname, perms)
  if not perms then
    perms = 493 -- 0755
  end
  if not M.exists(dirname) then
    local parent = vim.fn.fnamemodify(dirname, ":h")
    if not M.exists(parent) then
      M.mkdir(parent)
    end
    vim.loop.fs_mkdir(dirname, perms)
  end
end

---@param filename string
---@param contents string
M.write_file = function(filename, contents)
  M.mkdir(vim.fn.fnamemodify(filename, ":h"))
  local fd = vim.loop.fs_open(filename, "w", 420) -- 0644
  vim.loop.fs_write(fd, contents)
  vim.loop.fs_close(fd)
end

---@param filename string
M.delete_file = function(filename)
  if M.exists(filename) then
    vim.loop.fs_unlink(filename)
    return true
  end
end

---@param filename string
---@param obj any
M.write_json_file = function(filename, obj)
  M.write_file(filename, vim.json.encode(obj))
end

return M
