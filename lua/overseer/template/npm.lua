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

---@param bin string
---@param workspace_paths string[]
---@return table[]
local function add_workspace_tasks(bin, workspace_paths)
  local tasks = {}

  for _, workspace_path in ipairs(workspace_paths) do
    local workspace_package_file = vim.fs.joinpath(workspace_path, "package.json")
    local workspace_data = files.load_json_file(workspace_package_file)
    if workspace_data and workspace_data.scripts then
      for k in pairs(workspace_data.scripts) do
        table.insert(tasks, {
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

  return tasks
end

---@param content string
---@return table|nil
local function parse_pnpm_workspace_regex(content)
  local inclusions, exclusions = {}, {}

  local in_packages = false
  for line in content:gmatch("[^\n]+") do
    -- Check if we're entering the packages block
    if line:match("^packages%s*:") then
      in_packages = true

    -- Check if we're leaving the packages block (key at same indentation level)
    elseif in_packages and line:match("^%w+%s*:") and not line:match("^%s+%-") then
      in_packages = false

    -- If we're in the packages block, parse the patterns
    elseif in_packages then
      -- Match lines like "  - 'pattern'" or "  - \"pattern\""
      local pattern = line:match("%-[%s]*['\"]([^'\"]+)['\"]")
      if pattern then
        if pattern:sub(1, 1) == "!" then
          table.insert(exclusions, pattern:sub(2))
        else
          table.insert(inclusions, pattern)
        end
      end
    end
  end

  if #inclusions > 0 then
    return { inclusions = inclusions }
  end

  return nil
end

---@param filepath string
---@return table|nil
---Parse pnpm-workspace.yaml file and extract workspace patterns
---Uses treesitter if available, falls back to regex-based parsing
local function parse_pnpm_workspace(filepath)
  local content = files.read_file(filepath)
  if not content then
    return nil
  end

  local ok_parser, parser = pcall(vim.treesitter.get_string_parser, content, "yaml")
  if ok_parser and parser then
    local tree = parser:parse()
    local root = tree[1]:root()
    local inclusions, exclusions = {}, {}

    local query_str = [[
      (block_mapping_pair
        key: (flow_node
                (plain_scalar) @key)
        (#eq? @key "packages")
        value: (block_node
                  (block_sequence
                    (block_sequence_item
                      (flow_node
                        (_ ) @item)))))
    ]]

    local ok_query, query = pcall(vim.treesitter.query.parse, "yaml", query_str)
    if ok_query and query then
      for id, node in query:iter_captures(root, content) do
        local capture_name = query.captures[id]
        if capture_name == "item" then
          local text = vim.treesitter.get_node_text(node, content)

          -- Remove quotes and trim whitespace
          text = text:gsub("^[\"']", ""):gsub("[\"']$", ""):match("^%s*(.-)%s*$")

          if text and text ~= "" then
            if text:sub(1, 1) == "!" then
              table.insert(exclusions, text:sub(2))
            else
              table.insert(inclusions, text)
            end
          end
        end
      end

      if #inclusions > 0 then
        return { inclusions = inclusions }
      end
    end
  end

  -- Fallback to regex-based parsing
  return parse_pnpm_workspace_regex(content)
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

    -- Load tasks from workspaces in package.json
    if data.workspaces then
      -- Support both array format and Yarn v1 object format with .packages property
      local workspace_patterns = data.workspaces
      if type(data.workspaces) == "table" and data.workspaces.packages then
        workspace_patterns = data.workspaces.packages
      end
      local workspace_paths = resolve_workspace_paths(cwd, workspace_patterns)
      local workspace_tasks = add_workspace_tasks(bin, workspace_paths)
      for _, task in ipairs(workspace_tasks) do
        table.insert(ret, task)
      end
    end

    -- Load tasks from pnpm-workspace.yaml if it exists
    local pnpm_workspace_file = vim.fs.joinpath(cwd, "pnpm-workspace.yaml")
    if vim.uv.fs_stat(pnpm_workspace_file) then
      local pnpm_config = parse_pnpm_workspace(pnpm_workspace_file)
      if pnpm_config then
        local workspace_paths = resolve_workspace_paths(cwd, pnpm_config.inclusions)
        local workspace_tasks = add_workspace_tasks(bin, workspace_paths)
        for _, task in ipairs(workspace_tasks) do
          table.insert(ret, task)
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
