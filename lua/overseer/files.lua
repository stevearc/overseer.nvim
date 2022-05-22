local M = {}

M.is_windows = vim.loop.os_uname().version:match("Windows")

local sep = M.is_windows and "\\" or "/"

M.path_exists = function(filename)
  local stat = vim.loop.fs_stat(filename)
  return stat and stat.type or false
end

M.join = function(...)
  return table.concat({ ... }, sep)
end

M.is_subpath = function(dir, path)
  return string.sub(path, 0, string.len(dir)) == dir
end

M.get_cache_dir = function()
  return M.join(vim.fn.stdpath("cache"), "overseer")
end

M.write_cache_data = function(filename, data)
  local cache_dir = M.get_cache_dir()
  if not M.path_exists(cache_dir) then
    vim.loop.fs_mkdir(cache_dir, 493) -- 0755
  end
  local filepath = M.join(cache_dir, filename)
  local fd = vim.loop.fs_open(filepath, "w", 420) -- 0644
  vim.loop.fs_write(fd, vim.json.encode(data))
  vim.loop.fs_close(fd)
end

M.delete_cache_file = function(filename)
  local cache_dir = M.get_cache_dir()
  local filepath = M.join(cache_dir, filename)
  if M.path_exists(filepath) then
    vim.loop.fs_unlink(filepath)
    return true
  end
end

M.load_cache_data = function(filename)
  local cache_dir = M.get_cache_dir()
  local filepath = M.join(cache_dir, filename)
  if not M.path_exists(filepath) then
    vim.notify(string.format("No task bundle found at %s", filepath), vim.log.levels.ERROR)
    return
  end
  local fd = vim.loop.fs_open(filepath, "r", 420) -- 0644
  local stat = vim.loop.fs_fstat(fd)
  local content = vim.loop.fs_read(fd, stat.size)
  vim.loop.fs_close(fd)
  return vim.json.decode(content)
end

return M
