local constants = require("overseer.constants")
local json = require("overseer.json")
local TAG = constants.TAG

---@param opts overseer.SearchParams
---@return nil|string
local function get_cargo_file(opts)
  return vim.fs.find("Cargo.toml", { upward = true, type = "file", path = opts.dir })[1]
end

---@param cwd string
---@param cb fun(error: nil|string, workspace_root: nil|string)
local function get_workspace_root(cwd, cb)
  vim.system({ "cargo", "metadata", "--no-deps", "--format-version", "1" }, {
    cwd = cwd,
    text = true,
  }, function(out)
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

return {
  cache_key = function(opts)
    return get_cargo_file(opts)
  end,
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
      for _, root in ipairs(roots) do
        for _, command in ipairs(commands) do
          table.insert(ret, {
            name = string.format("cargo %s%s", table.concat(command.args, " "), root.postfix),
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
      end
      cb(ret)
    end)
  end,
}
