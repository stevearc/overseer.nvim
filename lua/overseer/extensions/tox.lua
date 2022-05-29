local files = require("overseer.files")
local M = {}

M.tox = {
  name = "tox",
  priority = 60,
  params = {
    args = { optional = true, type = "list" },
  },
  condition = {
    callback = function(self, opts)
      return files.exists(files.join(opts.dir, "tox.ini"))
    end,
  },
  metagen = function(self, opts)
    local content = files.read_file(files.join(opts.dir, "tox.ini"))
    local targets = {}
    for line in vim.gsplit(content, "\n") do
      local envlist = line:match("^envlist%s*=%s*(.+)$")
      if envlist then
        for t in vim.gsplit(envlist, "%s*,%s*") do
          if t:match("^[a-zA-Z0-9_%-]+$") then
            targets[t] = true
          end
        end
      end

      local name = line:match("^%[testenv:([a-zA-Z0-9_%-]+)%]")
      if name then
        targets[name] = true
      end
    end

    local ret = { self }
    for k in pairs(targets) do
      table.insert(ret, self:wrap(string.format("tox -e %s", k), { args = { "-e", k } }))
    end
    return ret
  end,
  builder = function(self, params)
    local cmd = { "tox" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

return M
