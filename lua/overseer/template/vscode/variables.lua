local files = require("overseer.files")
local M = {}

M.get_selected_text = function()
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
  local vscode_dir = vim.fn.finddir(".vscode", ".;")
  if vscode_dir == "" then
    return vim.fn.getcwd()
  else
    return vim.fn.fnamemodify(vscode_dir, ":p:h:h")
  end
end

---@param str string|table|nil
---@param params table
M.replace_vars = function(str, params)
  if not str then
    return nil
  end
  if type(str) == "table" then
    local ret = {}
    for k, substr in pairs(str) do
      ret[k] = M.replace_vars(substr, params)
    end
    return ret
  end
  return str:gsub("%${%a+:?%a*}", function(match)
    local name = match:sub(3, string.len(match) - 1)
    -- TODO does not support ${workspacefolder:VALUE}
    -- TODO does not support ${config:VALUE}
    -- TODO does not support ${command:VALUE}
    if name == "userHome" then
      return os.getenv("HOME")
    elseif name == "workspaceFolder" then
      return get_workspace_folder()
    elseif name == "workspaceFolderBasename" then
      return vim.fn.fnamemodify(vim.fn.getcwd(0), ":t")
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
    elseif name == "pathSeparator" then
      return files.sep
    elseif name:match("^env:") then
      return os.getenv(name:sub(5))
    elseif name:match("^input:") then
      return params[name:sub(7)]
    else
      return match
    end
  end)
end

return M
