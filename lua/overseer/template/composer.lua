local files = require("overseer.files")
local overseer = require("overseer")

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    local cmd = { "composer" }
    return {
      args = params.args,
      cmd = cmd,
      cwd = params.cwd,
    }
  end,
}

local function get_composer_file(opts)
  return vim.fs.find("composer.json", { upward = true, type = "file", path = opts.dir })[1]
end

return {
  cache_key = function(opts)
    return get_composer_file(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("composer") == 0 then
        return false, "executable composer not found"
      end
      if not get_composer_file(opts) then
        return false, "No composer.json file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local package = get_composer_file(opts)
    local data = files.load_json_file(package)
    local ret = {}
    local scripts = data.scripts
    if scripts then
      for k in pairs(scripts) do
        table.insert(
          ret,
          overseer.wrap_template(
            tmpl,
            { name = string.format("composer %s", k) },
            { args = { "run-script", k } }
          )
        )
      end
    end
    table.insert(ret, overseer.wrap_template(tmpl, { name = "composer" }))
    cb(ret)
  end,
}
