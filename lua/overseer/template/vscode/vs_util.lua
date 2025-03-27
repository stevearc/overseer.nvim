local files = require("overseer.files")
local M = {}

---Get the primary language for the workspace
---TODO this is VERY incomplete at the moment
---@return string|nil
M.get_workspace_language = function()
  if files.any_exists("setup.py", "setup.cfg", "pyproject.toml", "mypy.ini") then
    return "python"
  elseif files.any_exists("tsconfig.json") then
    return "typescript"
  elseif files.any_exists("package.json") then
    return "javascript"
  end
  -- TODO java
  -- TODO powershell
end

---@param dir string
---@return nil|string
local function find_tasks_file(dir)
  local vscode_dirs =
    vim.fs.find(".vscode", { upward = true, type = "directory", path = dir, limit = math.huge })
  for _, vscode_dir in ipairs(vscode_dirs) do
    local tasks_file = vim.fs.joinpath(vscode_dir, "tasks.json")
    if files.exists(tasks_file) then
      return tasks_file
    end
  end
end

---@param cwd string
---@param dir string
---@return nil|string
M.get_tasks_file = function(cwd, dir)
  -- Look for the tasks file relative to the cwd and only then fall back to searching from the dir
  return find_tasks_file(cwd) or find_tasks_file(dir)
end

---@param tasks_file string
---@return table
M.load_tasks_file = function(tasks_file)
  return files.load_json_file(tasks_file)
end

return M
