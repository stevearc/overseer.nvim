local files = require("overseer.files")
local variables = require("overseer.vscode.variables")
local vs_util = require("overseer.vscode.vs_util")
local vscode = require("overseer.vscode")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    local tasks_file = vs_util.get_tasks_file(vim.fn.getcwd(), opts.dir)
    if not tasks_file then
      return "No .vscode/tasks.json file found"
    end
    local content = vs_util.load_tasks_file(tasks_file)
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
    if content[os_key] then
      global_defaults = vim.tbl_deep_extend("force", global_defaults, content[os_key])
    end
    local ret = {}
    local precalculated_vars = variables.precalculate_vars()

    if content.tasks == nil then
      return "No 'tasks' key found in '.vscode/tasks.json'"
    end

    for _, task in ipairs(content.tasks) do
      local defn = vim.tbl_deep_extend("force", global_defaults, task)
      defn = vim.tbl_deep_extend("force", defn, task[os_key] or {})
      local tmpl = vscode.convert_vscode_task(defn, precalculated_vars)
      if tmpl then
        table.insert(ret, tmpl)
      end
    end
    return ret
  end,
}
