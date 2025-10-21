local files = require("overseer.files")
local overseer = require("overseer")
local util = require("overseer.util")

---@type table<string, string[]>
local mgr_lockfiles = {
  npm = { "package-lock.json" },
  pnpm = { "pnpm-lock.yaml" },
  yarn = { "yarn.lock" },
  bun = { "bun.lockb", "bun.lock" },
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
---@return string[]
local function get_candidate_package_files(opts)
  -- Some projects have package.json files in subfolders, which are not the main project package.json file,
  -- but rather some submodule marker. This seems prevalent in react-native projects. See this for instance:
  -- https://stackoverflow.com/questions/51701191/react-native-has-something-to-use-local-folders-as-package-name-what-is-it-ca
  -- To cover that case, we search for package.json files starting from the current file folder, up to the
  -- working directory
  local matches = vim.fs.find("package.json", {
    upward = true,
    type = "file",
    path = opts.dir,
    stop = vim.fn.getcwd() .. "/..",
    limit = math.huge,
  })
  if #matches > 0 then
    return matches
  end
  -- we couldn't find any match up to the working directory.
  -- let's now search for any possible single match without
  -- limiting ourselves to the working directory.
  return vim.fs.find("package.json", {
    upward = true,
    type = "file",
    path = vim.fn.getcwd(),
  })
end

---@param candidate_packages string[]
---@return string|nil
local function get_package_file(candidate_packages)
  -- go through candidate package files from closest to the file to least close
  for _, package in ipairs(candidate_packages) do
    local data = files.load_json_file(package)
    if data.scripts or data.workspaces then
      return package
    end
  end
  return nil
end

---@param candidate_packages string[]
---@return string
local function pick_package_manager(candidate_packages)
  -- go through candidate package files to find the nearest valid lockfile
  for _, package_file in ipairs(candidate_packages) do
    local package_dir = vim.fs.dirname(package_file)
    for mgr, lockfiles in pairs(mgr_lockfiles) do
      if
          util.list_any(lockfiles, function(lockfile)
            return files.exists(files.join(package_dir, lockfile))
          end)
      then
        return mgr
      end
    end
  end
  return "npm"
end

return {
  cache_key = function(opts)
    local candidate_packages = get_candidate_package_files(opts)
    return get_package_file(candidate_packages)
  end,
  condition = {
    callback = function(opts)
      local candidate_packages = get_candidate_package_files(opts)
      local package_file = get_package_file(candidate_packages)
      if not package_file then
        return false, "No package.json file found"
      end
      local package_manager = pick_package_manager(candidate_packages)
      if vim.fn.executable(package_manager) == 0 then
        return false, string.format("Could not find command '%s'", package_manager)
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local candidate_packages = get_candidate_package_files(opts)
    local package = get_package_file(candidate_packages)
    if not package then
      cb({})
      return
    end
    local bin = pick_package_manager(candidate_packages)
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
