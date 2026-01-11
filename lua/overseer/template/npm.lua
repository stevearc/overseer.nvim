local files = require("overseer.files")

---@type table<string, string[]>
local mgr_lockfiles = {
  npm = { "package-lock.json" },
  pnpm = { "pnpm-lock.yaml" },
  yarn = { "yarn.lock" },
  bun = { "bun.lockb", "bun.lock" },
}

---@param opts overseer.SearchParams
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

---@param package_dir string
---@return string|nil
local function detect_package_manager(package_dir)
  for mgr, lockfiles in pairs(mgr_lockfiles) do
    for _, lockfile in ipairs(lockfiles) do
      if vim.uv.fs_stat(vim.fs.joinpath(package_dir, lockfile)) then
        return mgr
      end
    end
  end
  return nil
end

---@param candidate_packages string[]
---@return { package: string, manager: string }|nil
---Determine the package.json file with scripts/workspaces and its package manager.
---Prioritizes packages with lockfiles, falls back to "npm" and closest package.json if no lockfile is found.
local function get_package_and_manager(candidate_packages)
  for _, package_file in ipairs(candidate_packages) do
    local data = files.load_json_file(package_file)
    if data.scripts or data.workspaces then
      local package_dir = vim.fs.dirname(package_file)
      local manager = detect_package_manager(package_dir)
      if manager then
        return { package = package_file, manager = manager }
      end
    end
  end

  for _, package_file in ipairs(candidate_packages) do
    local data = files.load_json_file(package_file)
    if data.scripts or data.workspaces then
      return { package = package_file, manager = "npm" }
    end
  end

  return nil
end

---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    local candidate_packages = get_candidate_package_files(opts)
    local result = get_package_and_manager(candidate_packages)
    if not result then
      return "No package.json file found"
    end
    local package = result.package
    local bin = result.manager
    if vim.fn.executable(bin) == 0 then
      return string.format("Could not find command '%s'", bin)
    end

    local data = files.load_json_file(package)
    local ret = {}
    local cwd = vim.fs.dirname(package)
    if data.scripts then
      for k in pairs(data.scripts) do
        table.insert(ret, {
          name = string.format("%s %s (%s)", bin, k, data.name),
          builder = function()
            return {
              cmd = { bin, "run", k },
              cwd = cwd,
            }
          end,
        })
      end
    end

    -- Load tasks from workspaces
    if data.workspaces then
      for _, workspace in ipairs(data.workspaces) do
        local workspace_path = vim.fs.joinpath(cwd, workspace)
        local workspace_package_file = vim.fs.joinpath(workspace_path, "package.json")
        local workspace_data = files.load_json_file(workspace_package_file)
        if workspace_data and workspace_data.scripts then
          for k in pairs(workspace_data.scripts) do
            table.insert(ret, {
              name = string.format("%s[%s] %s", bin, workspace, k),
              builder = function()
                return {
                  cmd = { bin, "run", k },
                  cwd = workspace_path,
                }
              end,
            })
          end
        end
      end
    end

    table.insert(ret, {
      name = bin .. " install",
      builder = function()
        return {
          cmd = { bin, "install" },
          cwd = cwd,
        }
      end,
    })
    return ret
  end,
}
