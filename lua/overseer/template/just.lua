local log = require("overseer.log")
local overseer = require("overseer")

---@param name string
---@return boolean
local function is_justfile(name)
  name = name:lower()
  return name == "justfile" or name == ".justfile"
end

---@param opts overseer.SearchParams
---@return nil|string
local function get_justfile(opts)
  return vim.fs.find(is_justfile, { upward = true, path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
local tmpl = {
  cache_key = function(opts)
    return get_justfile(opts)
  end,
  generator = function(opts, cb)
    if vim.fn.executable("just") == 0 then
      return 'Command "just" not found'
    end
    local justfile = get_justfile(opts)
    if not justfile then
      return "No justfile found"
    end
    local cwd = vim.fs.dirname(justfile)
    local ret = {}
    overseer.builtin.system(
      { "just", "--unstable", "--dump", "--dump-format", "json" },
      {
        cwd = cwd,
        text = true,
      },
      vim.schedule_wrap(function(out)
        if out.code ~= 0 then
          cb(out.stderr or out.stdout or "Error running 'just'")
          return
        end
        local ok, data = pcall(vim.json.decode, out.stdout, { luanil = { object = true } })
        if not ok then
          log.error("just produced invalid json: %s", out.stdout)
          cb(string.format("just produced invalid json: %s\n%s", data))
          return
        end
        assert(data)
        local get_recipes
        get_recipes = function(data)
          for _, recipe in pairs(data.recipes) do
            if not recipe.private then
              local params_defn = {}
              for _, param in ipairs(recipe.parameters) do
                params_defn[param.name] = {
                  default = param.default,
                  type = param.kind == "singular" and "string" or "list",
                  delimiter = " ",
                }
              end

              table.insert(ret, {
                name = string.format("just %s", recipe.namepath),
                desc = recipe.doc,
                params = params_defn,
                builder = function(params)
                  local cmd = { "just", recipe.namepath }
                  for _, param in ipairs(recipe.parameters) do
                    local v = params[param.name]
                    if v and v ~= "" then
                      if type(v) == "table" then
                        vim.list_extend(cmd, v)
                      else
                        table.insert(cmd, v)
                      end
                    end
                  end
                  return {
                    cmd = cmd,
                  }
                end,
              })
            end
          end
          for _, module in pairs(data.modules) do
            get_recipes(module)
          end
        end
        get_recipes(data)
        cb(ret)
      end)
    )
  end,
}

return tmpl
