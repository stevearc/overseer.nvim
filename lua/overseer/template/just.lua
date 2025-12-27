local log = require("overseer.log")
local overseer = require("overseer")

---@param name string
---@return boolean
local function is_justfile(name)
  name = name:lower()
  return name == "justfile" or name == ".justfile"
end

---@param task_list overseer.TemplateDefinition[]
---@param cwd string
---@param recipes table
local function add_recipes(task_list, cwd, recipes)
  for _, recipe in pairs(recipes) do
    if not recipe.private then
      local params_defn = {}
      for _, param in ipairs(recipe.parameters) do
        params_defn[param.name] = {
          default = param.default,
          type = param.kind == "singular" and "string" or "list",
          delimiter = " ",
        }
      end

      table.insert(task_list, {
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
            cwd = cwd,
          }
        end,
      })
    end
  end
end

---@param parent table
---@param candidate_module string
---@return boolean
local function includes_module(parent, candidate_module)
  for _, mod in pairs(parent.modules) do
    if mod.source == candidate_module then
      return true
    end
  end
  return false
end

---@param candidates string[]
---@param callback fun(err?: string, data?: table<string, table>)
local function fetch_justfile_data(candidates, callback)
  local cb
  local ret = {}
  local remaining = #candidates
  cb = function(err, justfile, data)
    if err then
      cb = function() end
      callback(err)
    else
      ret[justfile] = data
      remaining = remaining - 1
      if remaining == 0 then
        callback(nil, ret)
      end
    end
  end
  for _, justfile in ipairs(candidates) do
    local cwd = vim.fs.dirname(justfile)
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
        cb(nil, justfile, data)
      end)
    )
  end
end

---@type overseer.TemplateFileProvider
local tmpl = {
  cache_key = function(opts)
    return vim.fs.find(is_justfile, { upward = true, path = opts.dir })[1]
  end,
  generator = function(opts, cb)
    if vim.fn.executable("just") == 0 then
      return 'Command "just" not found'
    end
    local candidates =
      vim.fs.find(is_justfile, { upward = true, path = opts.dir, limit = math.huge })
    if vim.tbl_isempty(candidates) then
      return "No justfile found"
    end
    fetch_justfile_data(candidates, function(err, data_map)
      if err then
        cb(err)
        return
      end
      local ret = {}
      -- We look at each justfile from deepest path to highest path because the ancestors might
      -- include the nested ones as modules. We take the highest path that includes all others as
      -- modules.
      local selected_file
      for _, justfile in ipairs(candidates) do
        if not selected_file or includes_module(data_map[justfile], selected_file) then
          selected_file = justfile
        else
          break
        end
      end
      local cwd = vim.fs.dirname(selected_file)
      local data = data_map[selected_file]
      add_recipes(ret, cwd, data.recipes)
      if data.modules then
        for _, module in pairs(data.modules) do
          add_recipes(ret, cwd, module.recipes or {})
        end
      end
      cb(ret)
    end)
  end,
}

return tmpl
