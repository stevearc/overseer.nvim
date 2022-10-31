local log = require("overseer.log")

return {
  cache_key = function(opts)
    return vim.fn.fnamemodify(vim.fn.findfile("justfile", opts.dir .. ";"), ":p")
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("just") == 0 then
        return false, 'Command "just" not found'
      end
      if vim.fn.findfile("justfile", opts.dir .. ";") == "" then
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
        for k, recipe in pairs(data.recipes) do
          if recipe.private then
            goto continue
          end
          local params_defn = {}
          for _, param in ipairs(recipe.parameters) do
            params_defn[param.name] = {
              default = param.default,
              required = param.kind ~= "star",
              type = param.kind == "singular" and "string" or "list",
              delimiter = " ",
            }
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
                if type(v) == "string" then
                  table.insert(cmd, v)
                else
                  vim.list_extend(cmd, v)
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
