local constants = require("overseer.constants")
local log = require("overseer.log")
local overseer = require("overseer")
local util = require("overseer.util")
local TAG = constants.TAG

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { type = "list", delimiter = " " },
    cwd = { optional = true },
    relative_file_root = {
      desc = "Relative filepaths will be joined to this root (instead of task cwd)",
      optional = true,
    },
  },
  builder = function(params)
    return {
      cmd = { "cargo" },
      args = params.args,
      cwd = params.cwd,
      default_component_params = {
        errorformat = [[%Eerror: %\%%(aborting %\|could not compile%\)%\@!%m,]]
          .. [[%Eerror[E%n]: %m,]]
          .. [[%Inote: %m,]]
          .. [[%Wwarning: %\%%(%.%# warning%\)%\@!%m,]]
          .. [[%C %#--> %f:%l:%c,]]
          .. [[%E  left:%m,%C right:%m %f:%l:%c,%Z,]]
          .. [[%.%#panicked at \'%m\'\, %f:%l:%c]],
        relative_file_root = params.relative_file_root,
      },
    }
  end,
}

---@param opts overseer.SearchParams
---@return nil|string
local function get_cargo_file(opts)
  return vim.fs.find("Cargo.toml", { upward = true, type = "file", path = opts.dir })[1]
end

---@param cwd string
---@param cb fun(error: nil|string, workspace_root: nil|string)
local function get_workspace_root(cwd, cb)
  local jid = vim.fn.jobstart({ "cargo", "metadata", "--no-deps", "--format-version", "1" }, {
    cwd = cwd,
    stdout_buffered = true,
    on_stdout = function(j, output)
      local ok, data = pcall(util.decode_json, table.concat(output, ""))
      if ok then
        if data.workspace_root then
          cb(nil, data.workspace_root)
        else
          cb("No workspace_root found in output")
        end
      else
        cb(data)
      end
    end,
  })
  if jid == 0 then
    cb("Passed invalid arguments to 'cargo metadata'")
  elseif jid == -1 then
    cb("'cargo' is not executable")
  end
end

return {
  cache_key = function(opts)
    return get_cargo_file(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("cargo") == 0 then
        return false, 'Command "cargo" not found'
      end
      if not get_cargo_file(opts) then
        return false, "No Cargo.toml file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local cargo_dir = vim.fs.dirname(get_cargo_file(opts))
    local ret = {}

    get_workspace_root(cargo_dir, function(err, workspace_root)
      if err then
        log:error("Error fetching cargo workspace_root: %s", err)
        cb(ret)
        return
      end

      local commands = {
        { args = { "build" }, tags = { TAG.BUILD } },
        { args = { "test" }, tags = { TAG.TEST } },
        { args = { "check" } },
        { args = { "doc" } },
        { args = { "doc", "--open" } },
        { args = { "clean" } },
        { args = { "bench" } },
        { args = { "update" } },
        { args = { "publish" } },
        { args = { "run" } },
        { args = { "clippy" } },
        { args = { "fmt" } },
      }
      local roots =
        { {
          postfix = "",
          cwd = cargo_dir,
          priority = 55,
        } }
      if workspace_root ~= cargo_dir then
        roots[1].relative_file_root = workspace_root
        table.insert(roots, { postfix = " (workspace)", cwd = workspace_root })
      end
      for _, root in ipairs(roots) do
        for _, command in ipairs(commands) do
          table.insert(
            ret,
            overseer.wrap_template(
              tmpl,
              {
                name = string.format("cargo %s%s", table.concat(command.args, " "), root.postfix),
                tags = command.tags,
                priority = root.priority,
              },
              { args = command.args, cwd = root.cwd, relative_file_root = root.relative_file_root }
            )
          )
        end
        table.insert(
          ret,
          overseer.wrap_template(
            tmpl,
            { name = "cargo" .. root.postfix },
            { cwd = root.cwd, relative_file_root = root.relative_file_root }
          )
        )
      end
      cb(ret)
    end)
  end,
}
