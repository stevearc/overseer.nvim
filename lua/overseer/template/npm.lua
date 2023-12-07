local files = require("overseer.files")
local overseer = require("overseer")

local lockfiles = {
  npm = "package-lock.json",
  pnpm = "pnpm-lock.yaml",
  yarn = "yarn.lock",
  bun = "bun.lockb",
}

---@type overseer.TemplateFileDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
    cwd = { optional = true },
    bin = { optional = true, type = "string" },
  },
  builder = function(params)
    return {
      cmd = { params.bin },
      args = params.args,
      cwd = params.cwd,
    }
  end,
}

---@param opts overseer.SearchParams
local function get_package_file(opts)
  return vim.fs.find("package.json", { upward = true, type = "file", path = opts.dir })[1]
end

local function pick_package_manager(opts)
  local package_dir = vim.fs.dirname(get_package_file(opts))
  for mgr, lockfile in pairs(lockfiles) do
    if files.exists(files.join(package_dir, lockfile)) then
      return mgr
    end
  end
  return "npm"
end

return {
  cache_key = function(opts)
    return get_package_file(opts)
  end,
  condition = {
    callback = function(opts)
      if not get_package_file(opts) then
        return false, "No package.json file found"
      end
      local package_manager = pick_package_manager(opts)
      if vim.fn.executable(package_manager) == 0 then
        return false, string.format("Could not find command '%s'", package_manager)
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local package = get_package_file(opts)
    local bin = pick_package_manager(opts)
    local data = files.load_json_file(package)
    local ret = {}
    if data.scripts then
      for k in pairs(data.scripts) do
        table.insert(
          ret,
          overseer.wrap_template(
            tmpl,
            { name = string.format("%s %s", bin, k) },
            { args = { "run", k }, bin = bin, cwd = vim.fs.dirname(package) }
          )
        )
      end
    end

    -- Load tasks from workspaces
    if data.workspaces then
      for _, workspace in ipairs(data.workspaces) do
        local workspace_path = files.join(vim.fs.dirname(package), workspace)
        local workspace_package_file = files.join(workspace_path, "package.json")
        local workspace_data = files.load_json_file(workspace_package_file)
        if workspace_data and workspace_data.scripts then
          for k in pairs(workspace_data.scripts) do
            table.insert(
              ret,
              overseer.wrap_template(
                tmpl,
                { name = string.format("%s[%s] %s", bin, workspace, k) },
                { args = { "run", k }, bin = bin, cwd = workspace_path }
              )
            )
          end
        end
      end
    end
    table.insert(ret, overseer.wrap_template(tmpl, { name = bin }, { bin = bin }))
    cb(ret)
  end,
}
