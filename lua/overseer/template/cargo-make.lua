local files = require("overseer.files")
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
    local cmd = { "cargo-make", "make" }
    return {
      args = params.args,
      cmd = cmd,
      cwd = params.cwd,
    }
  end,
}

---@param opts overseer.SearchParams
---@return nil|string
local function get_cargo_make_file(opts)
  return vim.fs.find("Makefile.toml", { upward = true, type = "file", path = opts.dir })[1]
end

return {
  cache_key = function(opts)
    return get_cargo_make_file(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("cargo-make") == 0 then
        return false, 'Command "cargo-make" not found'
      end
      if not get_cargo_make_file(opts) then
        return false, 'No "Makefile.toml" file found'
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local ret = {}

    local cargo_make_file = get_cargo_make_file(opts)
    if not cargo_make_file then
      log.error("No Makefile.toml file found")
      cb(ret)
      return
    end
    local cargo_make_file_dir = vim.fs.dirname(cargo_make_file)

    local data = files.read_file(cargo_make_file)
    if not data then
      log.error("Failed to read Makefile.toml file")
      cb(ret)
      return
    end

    for s in vim.gsplit(data, "\n", { plain = true }) do
      local _, _, task_name = string.find(s, "^%[tasks%.(.+)%]$")
      if task_name ~= nil then
        table.insert(
          ret,
          overseer.wrap_template(
            tmpl,
            { name = string.format("cargo-make %s", task_name) },
            { args = { task_name }, cwd = cargo_make_file_dir }
          )
        )
      end
    end

    cb(ret)
  end,
}
