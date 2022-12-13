local files    = require('overseer.files')
local overseer = require('overseer')

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    local cmd = { "deno" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
      cwd = params.cwd,
    }
  end,
}

local function get_deno_file(opts)
  local deno_json = { 'deno.json', "deno.jsonc" }
  local filename = ""
  for i = 1, #deno_json do
    local results = vim.fn.findfile(deno_json[i], opts.dir .. ";")
    if results ~= "" then filename = results break end

  end
  if filename ~= "" then
    filename = vim.fn.fnamemodify(filename, ":p")
  end
  return filename
end

return {
  cache_key = function(opts)
    return get_deno_file(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("deno") == 0 then
        return false, 'executable deno not found'
      end
      if get_deno_file(opts) == "" then
        return false, "No deno.{json,jsonc} file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local package = get_deno_file(opts)
    local bin = "deno"
    local data = files.load_json_file(package)
    local ret = {}
    local tasks = data.tasks
    if tasks then
      for k in pairs(tasks) do
        table.insert(
          ret,
          overseer.wrap_template(
            tmpl,
            { name = string.format("%s %s", bin, k) },
            { args = { "task", k } }
          )
        )
      end
    end
    table.insert(ret, overseer.wrap_template(tmpl, { name = bin }))
    cb(ret)
  end,
}
