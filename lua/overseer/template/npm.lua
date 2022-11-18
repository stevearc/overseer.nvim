local files = require("overseer.files")
local overseer = require("overseer")

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
    use_yarn = { optional = true, type = "boolean" },
    cwd = { optional = true },
  },
  builder = function(params)
    local bin = params.use_yarn and "yarn" or "npm"
    local cmd = { bin }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
      cwd = params.cwd,
    }
  end,
}

local function get_package_file(opts)
  local filename = vim.fn.findfile("package.json", opts.dir .. ";")
  if filename ~= "" then
    filename = vim.fn.fnamemodify(filename, ":p")
  end
  return filename
end

return {
  cache_key = function(opts)
    return get_package_file(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("npm") == 0 and vim.fn.executable("yarn") == 0 then
        return false, 'Commands "npm" and "yarn" not found'
      end
      if get_package_file(opts) == "" then
        return false, "No package.json file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local package = get_package_file(opts)
    local use_yarn = files.exists(files.join(opts.dir, "yarn.lock"))
    local bin = use_yarn and "yarn" or "npm"
    local data = files.load_json_file(package)
    local ret = {}
    if data.scripts then
      for k in pairs(data.scripts) do
        table.insert(
          ret,
          overseer.wrap_template(
            tmpl,
            { name = string.format("%s %s", bin, k) },
            { args = { "run", k }, use_yarn = use_yarn }
          )
        )
      end
    end

    -- Load tasks from workspaces
    if data.workspaces then
      for _, workspace in ipairs(data.workspaces) do
        local workspace_path = files.join(vim.fn.fnamemodify(package, ":h"), workspace)
        local workspace_package_file = files.join(workspace_path, "package.json")
        local workspace_data = files.load_json_file(workspace_package_file)
        if workspace_data and workspace_data.scripts then
          for k in pairs(workspace_data.scripts) do
            table.insert(
              ret,
              overseer.wrap_template(
                tmpl,
                { name = string.format("%s[%s] %s", bin, workspace, k) },
                { args = { "run", k }, use_yarn = use_yarn, cwd = workspace_path }
              )
            )
          end
        end
      end
    end
    table.insert(ret, overseer.wrap_template(tmpl, { name = bin }, { use_yarn = use_yarn }))
    cb(ret)
  end,
}
