local files = require("overseer.files")
local log = require("overseer.log")
local M = {}

M.get_selected_text = function()
  local mode = vim.api.nvim_get_mode().mode
  if not vim.startswith(mode:lower(), "v") then
    return ""
  end
  local _, start_lnum, start_col, _ = unpack(vim.fn.getpos("v"))
  local _, end_lnum, end_col, _, _ = unpack(vim.fn.getcurpos())
  local swapped = false
  if end_lnum < start_lnum or (end_lnum == start_lnum and end_col < start_col) then
    start_col, end_col = end_col, start_col
    start_lnum, end_lnum = end_lnum, start_lnum
    swapped = true
  end
  local lines = vim.api.nvim_buf_get_lines(0, start_lnum - 1, end_lnum, true)
  if swapped then
    -- When selection range is backwards, we want to make sure that the end
    -- part of the selection includes the final char if it's multibyte
    end_col = end_col + vim.str_utf_end(lines[#lines], end_col)
  else
    -- HACK: one of the downsides of using getpos('v') is that when the visual
    -- range is highlighted *forwards*, the start col is off by 1.
    start_col = start_col - 1 + vim.str_utf_start(lines[1], start_col - 1)
  end
  lines[1] = string.sub(lines[1], start_col)
  lines[#lines] = string.sub(lines[#lines], 1, end_col)
  return table.concat(lines, "\n")
end

local function get_workspace_folder()
  local vscode_dir =
    vim.fs.find(".vscode", { upward = true, type = "directory", path = vim.fn.getcwd() })[1]
  if vscode_dir then
    return vim.fs.dirname(vscode_dir)
  else
    return vim.fn.getcwd()
  end
end

---@return table
M.precalculate_vars = function()
  return {
    workspaceFolder = get_workspace_folder(),
    workspaceFolderBasename = vim.fs.basename(vim.fn.getcwd()),
    file = vim.fn.expand("%:p"),
    fileWorkspaceFolder = get_workspace_folder(),
    relativeFile = vim.fn.expand("%:."),
    relativeFileDirname = vim.fn.expand("%:.:h"),
    fileBasename = vim.fn.expand("%:t"),
    fileBasenameNoExtension = vim.fn.expand("%:t:r"),
    fileDirname = vim.fn.expand("%:p:h"),
    fileExtname = vim.fn.expand("%:e"),
    lineNumber = vim.api.nvim_win_get_cursor(0)[1],
    selectedText = M.get_selected_text(),
  }
end

---@param str string|table|nil
---@param params table
---@param precalculated_vars? table
M.replace_vars = function(str, params, precalculated_vars)
  if not str then
    return nil
  end
  if type(str) == "table" then
    local ret = {}
    for k, substr in pairs(str) do
      ret[k] = M.replace_vars(substr, params, precalculated_vars)
    end
    return ret
  end
  return str:gsub("%${([^}:]+):?([^}]*)}", function(name, arg)
    if precalculated_vars and precalculated_vars[name] then
      return precalculated_vars[name]
    end
    if name == "userHome" then
      return assert(vim.loop.os_homedir())
    elseif name == "workspaceFolder" then
      return get_workspace_folder()
    elseif name == "workspaceRoot" then
      -- workspaceRoot is deprecated, but we'll treat it the same as workspaceFolder
      return get_workspace_folder()
    elseif name == "workspaceFolderBasename" then
      return vim.fs.basename(get_workspace_folder())
    elseif name == "file" then
      return vim.fn.expand("%:p")
    elseif name == "fileWorkspaceFolder" then
      return get_workspace_folder()
    elseif name == "relativeFile" then
      return vim.fn.expand("%:.")
    elseif name == "relativeFileDirname" then
      return vim.fn.expand("%:.:h")
    elseif name == "fileBasename" then
      return vim.fn.expand("%:t")
    elseif name == "fileBasenameNoExtension" then
      return vim.fn.expand("%:t:r")
    elseif name == "fileDirname" then
      return vim.fn.expand("%:p:h")
    elseif name == "fileExtname" then
      return vim.fn.expand("%:e")
    elseif name == "cwd" then
      return vim.loop.cwd()
    elseif name == "lineNumber" then
      return vim.api.nvim_win_get_cursor(0)[1]
    elseif name == "selectedText" then
      return M.get_selected_text()
    elseif name == "execPath" then
      return "code"
    elseif name == "defaultBuildTask" then
      -- FIXME dynamic call to find default build task
      return "BUILD"
    elseif name == "pathSeparator" or name == "/" then
      return files.sep
    elseif name == "env" then
      return os.getenv(arg)
    elseif name == "input" then
      return params[arg]
    else
      local fullname
      if arg ~= "" then
        fullname = string.format("${%s:%s}", name, arg)
      else
        fullname = string.format("${%s}", name)
      end
      -- TODO does not support ${workspacefolder:VALUE}
      -- TODO does not support ${config:VALUE}
      -- TODO does not support ${command:VALUE}
      if name == "workspacefolder" or name == "config" or name == "command" then
        log.warn("Unsupported VS Code variable: %s", fullname)
      end
      return fullname
    end
  end)
end

return M
