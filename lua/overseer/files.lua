local M = {}

M.is_windows = vim.loop.os_uname().version:match("Windows")

M.is_mac = vim.loop.os_uname().sysname == "Darwin"

M.sep = M.is_windows and "\\" or "/"

M.exists = function(filepath)
  local stat = vim.loop.fs_stat(filepath)
  return stat ~= nil and stat.type ~= nil
end

M.join = function(...)
  return table.concat({ ... }, M.sep)
end

M.is_subpath = function(dir, path)
  return string.sub(path, 0, string.len(dir)) == dir
end

M.get_data_dir = function()
  return M.join(vim.fn.stdpath("data"), "overseer")
end

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

M.gen_random_filename = function(data_dir, basename)
  local num = 0
  for _ = 1, 5 do
    num = 10 * num + math.random(0, 9)
  end
  local filename = basename:format(num)
  return M.join(vim.fn.stdpath(data_dir), "overseer", filename)
end

M.load_json_file = function(filepath)
  local content = M.read_file(filepath)
  if content then
    return vim.json.decode(content)
  end
end

M.data_file_exists = function(filename)
  local data_dir = M.get_data_dir()
  local filepath = M.join(data_dir, filename)
  return M.exists(filepath)
end

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

M.write_file = function(filename, contents)
  M.mkdir(vim.fn.fnamemodify(filename, ":h"))
  local fd = vim.loop.fs_open(filename, "w", 420) -- 0644
  vim.loop.fs_write(fd, contents)
  vim.loop.fs_close(fd)
end

M.delete_file = function(filename)
  if M.exists(filename) then
    vim.loop.fs_unlink(filename)
    return true
  end
end

M.write_data_file = function(filename, data)
  local data_dir = M.get_data_dir()
  M.mkdir(data_dir)
  local filepath = M.join(data_dir, filename)
  local fd = vim.loop.fs_open(filepath, "w", 420) -- 0644
  vim.loop.fs_write(fd, vim.json.encode(data))
  vim.loop.fs_close(fd)
end

M.delete_data_file = function(filename)
  local data_dir = M.get_data_dir()
  local filepath = M.join(data_dir, filename)
  return M.delete_file(filepath)
end

M.load_data_file = function(filename)
  local data_dir = M.get_data_dir()
  local filepath = M.join(data_dir, filename)
  return M.load_json_file(filepath)
end

return M
