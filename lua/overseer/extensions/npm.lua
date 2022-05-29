local files = require("overseer.files")
local M = {}

M.npm = {
  name = "npm",
  priority = 60,
  params = {
    args = { optional = true, type = "list" },
    use_yarn = { optional = true, type = "bool" },
  },
  condition = {
    callback = function(self, opts)
      return files.exists(files.join(opts.dir, "package.json"))
    end,
  },
  metagen = function(self, opts)
    local package = files.join(opts.dir, "package.json")
    local use_yarn = files.exists(files.join(opts.dir, "yarn.lock"))
    local bin = use_yarn and "yarn" or "npm"
    local data = files.load_json_file(package)
    local ret = {}
    if data.scripts then
      for k in pairs(data.scripts) do
        table.insert(
          ret,
          self:wrap(string.format("%s %s", bin, k), { args = { "run", k }, use_yarn = use_yarn })
        )
      end
    end
    table.insert(ret, self:wrap(bin, { use_yarn = use_yarn }))
    return ret
  end,
  builder = function(self, params)
    local bin = params.use_yarn and "yarn" or "npm"
    local cmd = { bin }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

return M
