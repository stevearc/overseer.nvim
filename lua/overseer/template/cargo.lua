local constants = require("overseer.constants")
local json = require("overseer.json")
local overseer = require("overseer")
local TAG = constants.TAG

---@param opts overseer.SearchParams
---@return nil|string
local function get_cargo_file(opts)
  return vim.fs.find("Cargo.toml", { upward = true, type = "file", path = opts.dir })[1]
end

---@param cwd string
---@param cb fun(error: nil|string, workspace_root: nil|string)
local function get_workspace_root(cwd, cb)
  overseer.builtin.system(
    { "cargo", "metadata", "--no-deps", "--format-version", "1" },
    {
      cwd = cwd,
      text = true,
    },
    vim.schedule_wrap(function(out)
      local ok, data = pcall(json.decode, out.stdout)
      if ok then
        if data.workspace_root then
          cb(nil, data.workspace_root)
        else
          cb("No workspace_root found in output")
        end
      else
        cb(data)
      end
    end)
  )
end

local commands = {
  { args = { "build" }, tags = { TAG.BUILD } },
  { args = { "run" }, tags = { TAG.RUN } },
  { args = { "test" }, tags = { TAG.TEST } },
  { args = { "clean" }, tags = { TAG.CLEAN } },
  { args = { "check" } },
  { args = { "doc" } },
  { args = { "doc", "--open" } },
  { args = { "bench" } },
  { args = { "update" } },
  { args = { "publish" } },
  { args = { "clippy" } },
  { args = { "fmt" } },
}

---Discover aliases in each root without changing how task templates are built.
---@param roots table[]
---@param on_commands fun(root: table, commands: table[])
---@param cb fun(err: string|nil)
local function get_commands(roots, on_commands, cb)
  local remaining = #roots
  local failed = false
  for _, root in ipairs(roots) do
    overseer.builtin.system(
      { "cargo", "--list", "--color", "never" },
      { cwd = root.cwd, text = true },
      vim.schedule_wrap(function(out)
        if failed then
          return
        elseif out.code ~= 0 then
          failed = true
          cb(out.stderr)
          return
        end
        local available = vim.deepcopy(commands)
        local by_command, aliases = {}, {}
        -- Index the copies, keeping the built-in command definitions unchanged.
        for _, command in ipairs(available) do
          by_command[table.concat(command.args, " ")] = command
        end
        for line in out.stdout:gmatch("[^\r\n]+") do
          local alias, expansion = line:match("^%s+(%S+)%s+alias:%s+(.+)$")
          if alias then
            aliases[alias] = vim.trim(expansion)
          end
        end
        local function resolve(expansion, seen)
          local first, rest = expansion:match("^(%S+)(.*)$")
          if not aliases[first] then
            return expansion
          elseif seen[first] then
            return nil
          end
          seen[first] = true
          return resolve(aliases[first] .. rest, seen)
        end
        for alias, expansion in vim.spairs(aliases) do
          local label = resolve(expansion, { [alias] = true })
          if label then
            local command = by_command[label]
            if not command then
              -- Execute the alias so Cargo preserves quoting and array arguments.
              command = { args = { alias }, label = label }
              by_command[label] = command
              table.insert(available, command)
            end
            command.aliases = command.aliases or {}
            table.insert(command.aliases, alias)
          end
        end
        on_commands(root, available)
        remaining = remaining - 1
        if remaining == 0 then
          cb(nil)
        end
      end)
    )
  end
end

return {
  -- Alias configuration can change independently of Cargo.toml, so do not cache.
  generator = function(opts, cb)
    if vim.fn.executable("cargo") == 0 then
      return 'Command "cargo" not found'
    end
    local cargo_file = get_cargo_file(opts)
    if not cargo_file then
      return "No Cargo.toml file found"
    end
    local cargo_dir = vim.fs.dirname(cargo_file)
    local ret = {}

    get_workspace_root(cargo_dir, function(err, workspace_root)
      if err then
        return cb(err)
      end

      local roots = { {
        postfix = "",
        cwd = cargo_dir,
      } }
      if workspace_root ~= cargo_dir then
        roots[1].relative_file_root = workspace_root
        table.insert(roots, { postfix = " (workspace)", cwd = workspace_root })
      end
      get_commands(roots, function(root, available_commands)
        for _, command in ipairs(available_commands) do
          local label = command.label or table.concat(command.args, " ")
          local aliases = command.aliases and " (" .. table.concat(command.aliases, ", ") .. ")"
            or ""
          table.insert(ret, {
            name = string.format("cargo %s%s%s", label, aliases, root.postfix),
            aliases = { "cargo " .. label .. root.postfix },
            tags = command.tags,
            builder = function()
              return {
                cmd = vim.list_extend({ "cargo" }, command.args),
                cwd = root.cwd,
                default_component_params = {
                  errorformat = [[%Eerror: %\%%(aborting %\|could not compile%\)%\@!%m,]]
                    .. [[%Eerror[E%n]: %m,]]
                    .. [[%Inote: %m,]]
                    .. [[%Wwarning: %\%%(%.%# warning%\)%\@!%m,]]
                    .. [[%C %#--> %f:%l:%c,]]
                    .. [[%E  left:%m,%C right:%m %f:%l:%c,%Z,]]
                    .. [[%.%#panicked at \'%m\'\, %f:%l:%c]],
                  relative_file_root = root.relative_file_root,
                },
              }
            end,
          })
        end
      end, function(alias_err)
        cb(alias_err or ret)
      end)
    end)
  end,
}
