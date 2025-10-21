local json = require("overseer.json")
local log = require("overseer.log")
local overseer = require("overseer")

---@type overseer.TemplateFileDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    local cmd = { "devenv" }
    return {
      args = params.args,
      cmd = cmd,
      cwd = params.cwd,
    }
  end,
}

local function get_devenv_file(opts)
  local devenv_nix = { "devenv.nix" }
  return vim.fs.find(devenv_nix, { upward = true, type = "file", path = opts.dir })[1]
end

return {
  cache_key = function(opts)
    return get_devenv_file(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("devenv") == 0 then
        return false, "executable devenv not found"
      end
      if not get_devenv_file(opts) then
        return false, "No devenv.nix file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local devenv = get_devenv_file(opts)
    local devenv_dir = vim.fs.dirname(devenv)
    local ret = {}
    local jid = vim.fn.jobstart({
      "devenv",
      "shell",
      "echo $DEVENV_TASKS",
    }, {
      cwd = devenv_dir,
      stdout_buffered = true,
      on_stdout = vim.schedule_wrap(function(j, output)
        local ok, data =
          pcall(vim.json.decode, table.concat(output, "\n"), { luanil = { object = true } })

        if not ok then
          log:error("Devenv taskfile produced invalid json: %s\n%s", data, output)
          cb(ret)
          return
        end

        assert(data)

        for _, task in ipairs(data) do
          table.insert(
            ret,
            overseer.wrap_template(
              tmpl,
              { name = string.format("devenv %s", task.name) },
              { args = { "tasks", "run", task.name }, cwd = devenv_dir }
            )
          )
        end

        cb(ret)
      end),
    })

    if jid == 0 then
      log:error("Passed invalid arguments to 'devenv shell'")
      cb(ret)
    elseif jid == -1 then
      log:error("'devenv' is not executable")
      cb(ret)
    end
  end,
}
