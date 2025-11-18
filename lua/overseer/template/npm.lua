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

---@param candidate_packages string[]
---@return string|nil
local function get_package_file(candidate_packages)
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
---Determine the appropriate package manager by checking for known lockfiles located in the same directories as the provided package.json files.
---Falls back to "npm" if none are found.
local function pick_package_manager(candidate_packages)
  for _, package_file in ipairs(candidate_packages) do
    local package_dir = vim.fs.dirname(package_file)
    for mgr, lockfiles in pairs(mgr_lockfiles) do
      for _, lockfile in ipairs(lockfiles) do
        if vim.uv.fs_stat(vim.fs.joinpath(package_dir, lockfile)) then
          return mgr
        end
      end
    end
  end
  return "npm"
end

---@param base_path string
---@param workspace_patterns string[]
---@return string[]
---Resolve workspace patterns to actual directories containing package.json
---Supports glob patterns: *, **, ?, [...]
local function resolve_workspace_paths(base_path, workspace_patterns)
  local resolved = {}
  local seen = {}

  for _, pattern in ipairs(workspace_patterns) do
    local glob_path = vim.fs.joinpath(base_path, pattern)
    local matches = vim.fn.glob(glob_path, false, true)
    if type(matches) == "string" then
      matches = { matches }
    elseif not matches or vim.tbl_isempty(matches) then
      goto continue
    end

    for _, match in ipairs(matches) do
      local package_json_path = vim.fs.joinpath(match, "package.json")
      if vim.uv.fs_stat(package_json_path) and not seen[match] then
        table.insert(resolved, match)
        seen[match] = true
      end
    end

    ::continue::
  end

  return resolved
end

---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    local candidate_packages = get_candidate_package_files(opts)
    local package = get_package_file(candidate_packages)
    if not package then
      return "No package.json file found"
    end
    local bin = pick_package_manager(candidate_packages)
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
      -- Support both array format and Yarn v1 object format with .packages property
      local workspace_patterns = data.workspaces
      if type(data.workspaces) == "table" and data.workspaces.packages then
        workspace_patterns = data.workspaces.packages
      end
      local workspace_paths = resolve_workspace_paths(cwd, workspace_patterns)
      for _, workspace_path in ipairs(workspace_paths) do
        local workspace_package_file = vim.fs.joinpath(workspace_path, "package.json")
        local workspace_data = files.load_json_file(workspace_package_file)
        if workspace_data and workspace_data.scripts then
          for k in pairs(workspace_data.scripts) do
            table.insert(ret, {
              name = string.format("%s[workspace] %s (%s)", bin, k, workspace_data.name),
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
    return ret
  end,
}
