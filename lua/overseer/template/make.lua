local overseer = require("overseer")
local files = require("overseer.files")
local M = {}

M.make = {
  name = "make",
  tags = { overseer.TAG.BUILD },
  params = {
    args = { optional = true, type = "list" },
  },
  condition = {
    callback = function(self, opts)
      return files.exists(files.join(opts.dir, "Makefile"))
    end,
  },
  metagen = function(self, opts)
    local content = files.read_file(files.join(opts.dir, "Makefile"))
    local targets = {}
    for line in vim.gsplit(content, "\n") do
      local name = line:match("^([a-zA-Z_]+)%s*:")
      if name then
        targets[name] = true
      else
        local phony = line:match("^%.PHONY%s*: (.+)$")
        if phony then
          for _, t in vim.gsplit(phony, "%s+") do
            -- TODO we could be fancy and try to figure out the variable
            -- substitution, but for now let's just take the easy targets
            if t:match("^[a-zA-Z_]+$") then
              targets[t] = true
            end
          end
        end
      end
    end

    local ret = {}
    for k in pairs(targets) do
      table.insert(ret, self:wrap(string.format("make %s", k), { args = { k } }))
    end
    return ret
  end,
  builder = function(self, params)
    local cmd = { "make" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

return M
