local files = require("overseer.files")
local overseer = require("overseer")

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
    use_yarn = { optional = true, type = "boolean" },
  },
  builder = function(params)
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

local function get_package_file(opts)
  local filename = vim.fn.findfile("package.json", opts.dir .. ";")
  if filename ~= "" then
    filename = vim.fn.fnamemodify(filename, ":p")
  end
  return filename
end

return {
  cache_key = function(opts)
    return get_package_file(opts)
  end,
  condition = {
    callback = function(opts)
      return get_package_file(opts) ~= ""
    end,
  },
  generator = function(opts, cb)
    local package = get_package_file(opts)
    local use_yarn = files.exists(files.join(opts.dir, "yarn.lock"))
    local bin = use_yarn and "yarn" or "npm"
    local data = files.load_json_file(package)
    local ret = {}
    if data.scripts then
      for k in pairs(data.scripts) do
        table.insert(
          ret,
          overseer.wrap_template(
            tmpl,
            { name = string.format("%s %s", bin, k) },
            { args = { "run", k }, use_yarn = use_yarn }
          )
        )
      end
    end
    table.insert(ret, overseer.wrap_template(tmpl, { name = bin }, { use_yarn = use_yarn }))
    cb(ret)
  end,
}
