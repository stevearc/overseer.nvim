local M = {}

M.is_windows = vim.loop.os_uname().version:match("Windows")

local sep = M.is_windows and "\\" or "/"

M.exists = function(filepath)
  local stat = vim.loop.fs_stat(filepath)
  return stat and stat.type or false
end

M.join = function(...)
  return table.concat({ ... }, sep)
end

M.is_subpath = function(dir, path)
  return string.sub(path, 0, string.len(dir)) == dir
end

M.get_data_dir = function()
  return M.join(vim.fn.stdpath("data"), "overseer")
end

M.read_file = function(filepath)
  if not M.exists(filepath) then
    vim.notify(string.format("No such file %s", filepath), vim.log.levels.ERROR)
    return
  end
  local fd = vim.loop.fs_open(filepath, "r", 420) -- 0644
  local stat = vim.loop.fs_fstat(fd)
  local content = vim.loop.fs_read(fd, stat.size)
  vim.loop.fs_close(fd)
  return content
end

M.load_json_file = function(filepath)
  local content = M.read_file(filepath)
  if content then
    return vim.json.decode(content)
  end
end

M.write_data_file = function(filename, data)
  local data_dir = M.get_data_dir()
  if not M.exists(data_dir) then
    vim.loop.fs_mkdir(data_dir, 493) -- 0755
  end
  local filepath = M.join(data_dir, filename)
  local fd = vim.loop.fs_open(filepath, "w", 420) -- 0644
  vim.loop.fs_write(fd, vim.json.encode(data))
  vim.loop.fs_close(fd)
end

M.delete_data_file = function(filename)
  local data_dir = M.get_data_dir()
  local filepath = M.join(data_dir, filename)
  if M.exists(filepath) then
    vim.loop.fs_unlink(filepath)
    return true
  end
end

M.load_data_file = function(filename)
  local data_dir = M.get_data_dir()
  local filepath = M.join(data_dir, filename)
  return M.load_json_file(filepath)
end

return M
