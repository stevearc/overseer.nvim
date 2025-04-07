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
    local cmd = { "mise", "run" }
    return {
      args = params.args,
      cmd = cmd,
      cwd = params.cwd,
    }
  end,
}

---@param opts overseer.SearchParams
---@return nil|string
local function get_mise_file(opts)
  local is_misefile = function(name)
    name = name:lower()
    return name == "mise.toml" or name == ".mise.toml"
  end
  return vim.fs.find(is_misefile, { upward = true, path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
local provider = {
  cache_key = function(opts)
    return get_mise_file(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("mise") == 0 then
        return false, 'Command "mise" not found'
      end
      if not get_mise_file(opts) then
        return false, "No mise.toml found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local ret = {}
    local jid = vim.fn.jobstart({ "mise", "tasks", "--json" }, {
      stdout_buffered = true,
      on_stdout = vim.schedule_wrap(function(_, output)
        local ok, data =
          pcall(vim.json.decode, table.concat(output, ""), { luanil = { object = true } })
        if not ok then
          log:error("mise produced invalid json: %s\n%s", data, output)
          cb(ret)
          return
        end
        assert(data)
        for _, value in pairs(data) do
          table.insert(
            ret,
            overseer.wrap_template(tmpl, {
              name = string.format("mise %s", value.name),
              desc = value.description ~= "" and value.description or nil,
            }, {
              args = { value.name },
              cwd = opts.dir,
            })
          )
        end
        cb(ret)
      end),
    })
    if jid == 0 then
      log:error('Passed invalid arguments to "mise tasks"')
      cb(ret)
    elseif jid == -1 then
      log:error('"mise" is not executable')
      cb(ret)
    end
  end,
}

return provider
