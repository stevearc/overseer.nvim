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
M.get_tasks_file = function(dir)
  return files.findfile('tasks.json', files.join(dir, '.vscode'), true)
end

---@param dir string
---@return table
M.load_tasks_file = function(dir)
  return files.load_json_file(M.get_tasks_file(dir))
end

return M
