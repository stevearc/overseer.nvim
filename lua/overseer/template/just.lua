local log = require("overseer.log")

---@param opts overseer.SearchParams
---@return nil|string
local function get_justfile(opts)
  local is_justfile = function(name)
    name = name:lower()
    return name == "justfile" or name == ".justfile"
  end
  return vim.fs.find(is_justfile, { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
local tmpl = {
  cache_key = function(opts)
    return get_justfile(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("just") == 0 then
        return false, 'Command "just" not found'
      end
      if not get_justfile(opts) then
        return false, "No justfile found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local ret = {}
    local jid = vim.fn.jobstart({ "just", "--unstable", "--dump", "--dump-format", "json" }, {
      cwd = opts.dir,
      stdout_buffered = true,
      on_stdout = vim.schedule_wrap(function(j, output)
        local ok, data =
          pcall(vim.json.decode, table.concat(output, ""), { luanil = { object = true } })
        if not ok then
          log:error("just produced invalid json: %s\n%s", data, output)
          cb(ret)
          return
        end
        assert(data)
        for k, recipe in pairs(data.recipes) do
          if recipe.private then
            goto continue
          end
          local params_defn = {}
          for _, param in ipairs(recipe.parameters) do
            local param_defn = {
              default = param.default,
              type = param.kind == "singular" and "string" or "list",
              delimiter = " ",
            }
            -- We don't want "star" arguments to be optional = true because then we won't show the
            -- input form. Instead, let's set a default value and filter it out in the builder.
            if param.kind == "star" and param.default == nil then
              if param_defn.type == "string" then
                param_defn.default = ""
              else
                param_defn.default = {}
              end
            end
            params_defn[param.name] = param_defn
          end
          table.insert(ret, {
            name = string.format("just %s", recipe.name),
            desc = recipe.doc,
            priority = k == data.first and 55 or 60,
            params = params_defn,
            builder = function(params)
              local cmd = { "just", recipe.name }
              for _, param in ipairs(recipe.parameters) do
                local v = params[param.name]
                if v then
                  if type(v) == "table" then
                    vim.list_extend(cmd, v)
                  elseif v ~= "" then
                    table.insert(cmd, v)
                  end
                end
              end
              return {
                cmd = cmd,
              }
            end,
          })
          ::continue::
        end
        cb(ret)
      end),
    })
    if jid == 0 then
      log:error("Passed invalid arguments to 'just'")
      cb(ret)
    elseif jid == -1 then
      log:error("'just' is not executable")
      cb(ret)
    end
  end,
}

return tmpl
