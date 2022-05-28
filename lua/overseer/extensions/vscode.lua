local constants = require("overseer.constants")
local files = require("overseer.files")
local template = require("overseer.template")

local M = {}

M.get_cmd = function(defn)
  if defn.type == "process" then
    local cmd = defn.args or {}
    table.insert(cmd, 1, defn.command)
    return cmd
  else
    local args = {}
    for _, arg in ipairs(defn.args or {}) do
      if type(arg) == "string" then
        table.insert(args, vim.fn.shellescape(arg))
      else
        -- TODO we are ignoring the quoting option for now
        table.insert(args, vim.fn.shellescape(arg.value))
      end
    end
    local cmd = defn.command
    if cmd:match("%s") then
      cmd = vim.fn.shellescape(cmd)
    end
    if #args > 0 then
      return string.format("%s %s", defn.command, table.concat(args, " "))
    else
      return cmd
    end
  end
end

local function parse_params(params, str, inputs)
  if not str then
    return
  end
  for name in string.gmatch(str, "%${input:(%a+)}") do
    local schema = inputs[name]
    if schema then
      if schema.type == "pickString" then
        -- FIXME encode the options
        params[name] = { description = schema.description, default = schema.default }
      elseif schema.type == "promptString" then
        params[name] = { description = schema.description, default = schema.default }
      elseif schema.type == "command" then
        -- TODO command inputs not supported yet
      end
    end
  end
end

M.parse_params = function(defn)
  if not defn.inputs then
    return {}
  end
  local input_lookup = {}
  for _, input in ipairs(defn.inputs) do
    input_lookup[input.id] = input
  end
  local params = {}
  parse_params(params, defn.command, input_lookup)
  if defn.args then
    for _, arg in ipairs(defn.args) do
      parse_params(params, arg, input_lookup)
    end
  end

  local opt = defn.options
  if opt then
    parse_params(params, opt.cwd, input_lookup)
    if opt.env then
      for _, v in pairs(opt.env) do
        parse_params(params, v, input_lookup)
      end
    end
  end
  -- TODO opt.shell not supported yet

  return params
end

local group_to_tag = {
  test = constants.TAG.TEST,
  build = constants.TAG.BUILD,
}

M.convert_vscode_task = function(defn)
  -- TODO we only support shell & process tasks
  if defn.type ~= "shell" and defn.type ~= "process" then
    return nil
  end
  local cmd = M.get_cmd(defn)
  local opt = defn.options

  local tmpl = {
    name = defn.label,
    params = M.parse_params(defn),
    builder = function(self, params)
      local task = {
        name = defn.label,
        cmd = M.replace_vars(cmd, params),
      }
      if opt then
        if opt.cwd then
          task.cwd = M.replace_vars(opt.cwd, params)
        end
        if opt.env then
          local env = {}
          for k, v in pairs(opt.env) do
            env[k] = M.replace_vars(v, params)
          end
          task.env = env
        end
      end

      return task
    end,
  }

  if defn.group then
    if type(defn.group) == "string" then
      tmpl.tags = { group_to_tag[defn.group] }
    else
      tmpl.tags = { group_to_tag[defn.group.kind] }
      -- TODO handle isDefault
    end
  end

  -- FIXME problemMatcher

  -- TODO defn.isBackground
  -- NOTE: we ignore defn.presentation
  -- NOTE: we intentionally do nothing with defn.runOptions.
  -- runOptions.reevaluateOnRun unfortunately doesn't mesh with how we re-run tasks
  -- runOptions.runOn allows tasks ot auto-run, which I philosophically oppose
  return template.new(tmpl)
end

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

M.replace_vars = function(str, params)
  if type(str) == "table" then
    local ret = {}
    for _, substr in ipairs(str) do
      local interp = M.replace_vars(substr, params)
      table.insert(ret, interp)
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
      return vim.fn.getcwd(0)
    elseif name == "workspaceFolderBasename" then
      return vim.fn.fnamemodify(vim.fn.getcwd(0), ":t")
    elseif name == "file" then
      return vim.fn.expand("%:p")
    elseif name == "fileWorkspaceFolder" then
      return vim.fn.getcwd(0)
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

M.vscode_tasks = {
  name = "vscode_tasks",
  params = {},
  condition = {
    callback = function(self, opts)
      return files.exists(files.join(opts.dir, ".vscode", "tasks.json"))
    end,
  },
  metagen = function(self, opts)
    local content = files.load_json_file(files.join(opts.dir, ".vscode", "tasks.json"))
    local global_defaults = {}
    for k, v in pairs(content) do
      if k ~= "version" and k ~= "tasks" then
        global_defaults[k] = v
      end
    end
    local os_key
    if files.is_windows then
      os_key = "windows"
    elseif files.is_mac then
      os_key = "osx"
    else
      os_key = "linux"
    end
    local ret = {}
    for _, task in ipairs(content.tasks) do
      local defn = vim.tbl_deep_extend("keep", task, global_defaults)
      defn = vim.tbl_deep_extend("force", defn, task[os_key] or {})
      local tmpl = M.convert_vscode_task(defn)
      if tmpl then
        table.insert(ret, tmpl)
      end
    end
    return ret
  end,
  builder = function() end,
}

return M
