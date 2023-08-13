local files = require("overseer.files")
local overseer = require("overseer")

---@type overseer.TemplateDefinition
local tmpl = {
  name = "tox",
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
  },
  builder = function(params)
    local cmd = { "tox" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

---@param opts overseer.SearchParams
---@return nil|string
local function get_toxfile(opts)
  return vim.fs.find("tox.ini", { upward = true, type = "file", path = opts.dir })[1]
end

return {
  cache_key = function(opts)
    return get_toxfile(opts)
  end,
  condition = {
    callback = function(opts)
      if not get_toxfile(opts) then
        return false, "No tox.ini file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local tox_file = assert(get_toxfile(opts))
    local content = assert(files.read_file(tox_file))
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

    local ret = { tmpl }
    for k in pairs(targets) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("tox -e %s", k) },
          { args = { "-e", k } }
        )
      )
    end
    cb(ret)
  end,
}
