local overseer = require("overseer")

---@param opts overseer.SearchParams
---@return nil|string
local function get_rakefile(opts)
  return vim.fs.find("Rakefile", { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return get_rakefile(opts)
  end,
  generator = function(opts, cb)
    if vim.fn.executable("rake") == 0 then
      return 'Command "rake" not found'
    end
    local rakefile = get_rakefile(opts)
    if not rakefile then
      return "No Rakefile found"
    end
    local cwd = vim.fs.dirname(rakefile)
    local ret = {}
    overseer.builtin.system(
      { "rake", "-T" },
      {
        cwd = cwd,
        text = true,
      },
      vim.schedule_wrap(function(out)
        if out.code ~= 0 then
          return cb(out.stderr or out.stdout or "Error running 'rake -T'")
        end
        local tasks = {}
        for line in vim.gsplit(out.stdout, "\n") do
          if line ~= "" then
            local task_name, params = line:match("^rake (%S+)(%[%S+%])")
            if task_name == nil then
              -- no parameters
              task_name = line:match("^rake (%S+)")
            end
            if task_name ~= nil then
              local param_names = {}
              local args = {}
              if params ~= nil then
                local idx = 1
                for token in string.gmatch(params, "[^,%[%]]+") do
                  table.insert(param_names, token)
                  args[token] = { type = "string", default = "", order = idx }
                  idx = idx + 1
                end
              end
              table.insert(tasks, { task_name = task_name, args = args, param_names = param_names })
            end
          end
        end
        for _, task in ipairs(tasks) do
          table.insert(ret, {
            name = string.format("rake %s", task.task_name),
            params = task.args,
            builder = function(parms)
              local param_vals = {}
              for _, param_name in ipairs(task.param_names) do
                table.insert(param_vals, parms[param_name])
              end
              local p = ""
              if #param_vals > 0 then
                p = "[" .. table.concat(param_vals, ",") .. "]"
              end
              return {
                cmd = { "rake", task.task_name .. p },
              }
            end,
          })
        end

        cb(ret)
      end)
    )
  end,
}
