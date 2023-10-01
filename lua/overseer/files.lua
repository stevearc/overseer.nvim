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
  local joined = table.concat({ ... }, M.sep)
  if M.is_windows then
    joined = joined:gsub("\\\\+", "\\")
  else
    joined = joined:gsub("//+", "/")
  end
  return joined
end

M.is_absolute = function(path)
  if M.is_windows then
    return path:lower():match("^%a:")
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

--- Returns true if candidate is a subpath of root, or if they are the same path.
---@param root string
---@param candidate string
---@return boolean
M.is_subpath = function(root, candidate)
  if candidate == "" then
    return false
  end
  root = vim.fs.normalize(M.abspath(root))
  -- Trim trailing "/" from the root
  if root:find("/", -1) then
    root = root:sub(1, -2)
  end
  candidate = vim.fs.normalize(M.abspath(candidate))
  if M.is_windows then
    root = root:lower()
    candidate = candidate:lower()
  end
  if root == candidate then
    return true
  end
  local prefix = candidate:sub(1, root:len())
  if prefix ~= root then
    return false
  end

  local candidate_starts_with_sep = candidate:find("/", root:len() + 1, true) == root:len() + 1
  local root_ends_with_sep = root:find("/", root:len(), true) == root:len()

  return candidate_starts_with_sep or root_ends_with_sep
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
  local fd = assert(vim.loop.fs_open(filepath, "r", 420)) -- 0644
  local stat = assert(vim.loop.fs_fstat(fd))
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
  local json = require("overseer.json")
  local content = M.read_file(filepath)
  if content then
    return json.decode(content)
  end
end

---@param dir string
---@return string[]
M.list_files = function(dir)
  ---@diagnostic disable-next-line: param-type-mismatch
  local fd = vim.loop.fs_opendir(dir, nil, 32)
  ---@diagnostic disable-next-line: param-type-mismatch
  local entries = vim.loop.fs_readdir(fd)
  local ret = {}
  while entries do
    for _, entry in ipairs(entries) do
      if entry.type == "file" then
        table.insert(ret, entry.name)
      end
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    entries = vim.loop.fs_readdir(fd)
  end
  ---@diagnostic disable-next-line: param-type-mismatch
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
    local parent = vim.fs.dirname(dirname)
    if not M.exists(parent) then
      M.mkdir(parent)
    end
    vim.loop.fs_mkdir(dirname, perms)
  end
end

---@param filename string
---@param contents string
M.write_file = function(filename, contents)
  M.mkdir(vim.fn.fnamemodify(filename, ":p:h"))
  local fd = assert(vim.loop.fs_open(filename, "w", 420)) -- 0644
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
  ---@type string
  local serialized = vim.json.encode(obj) ---@diagnostic disable-line: assign-type-mismatch
  M.write_file(filename, serialized)
end

return M
