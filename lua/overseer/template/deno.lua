local files = require("overseer.files")
local overseer = require("overseer")

---@type overseer.TemplateFileDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    local cmd = { "deno" }
    return {
      args = params.args,
      cmd = cmd,
      cwd = params.cwd,
    }
  end,
}

local function get_deno_file(opts)
  local deno_json = { "deno.json", "deno.jsonc" }
  return vim.fs.find(deno_json, { upward = true, type = "file", path = opts.dir })[1]
end

return {
  cache_key = function(opts)
    return get_deno_file(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("deno") == 0 then
        return false, "executable deno not found"
      end
      if not get_deno_file(opts) then
        return false, "No deno.{json,jsonc} file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local package = get_deno_file(opts)
    local data = files.load_json_file(package)
    local ret = {}
    local tasks = data.tasks
    if tasks then
      for k in pairs(tasks) do
        table.insert(
          ret,
          overseer.wrap_template(
            tmpl,
            { name = string.format("deno %s", k) },
            { args = { "task", k } }
          )
        )
      end
    end
    table.insert(ret, overseer.wrap_template(tmpl, { name = "deno" }))
    cb(ret)
  end,
}
