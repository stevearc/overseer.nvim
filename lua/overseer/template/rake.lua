local log = require("overseer.log")

return {
  cache_key = function(opts)
    return vim.fn.fnamemodify(vim.fn.findfile("Rakefile", opts.dir .. ";"), ":p")
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("rake") == 0 then
        return false, 'Command "rake" not found'
      end
      if vim.fn.findfile("Rakefile", opts.dir .. ";") == "" then
        return false, "No Rakefile found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local ret = {}
    local jid = vim.fn.jobstart({
      "rake",
      "-T",
    }, {
      cwd = opts.dir,
      stdout_buffered = true,
      on_stdout = vim.schedule_wrap(function(j, output)
        local tasks = {}
        for _, line in ipairs(output) do
          if #line > 0 then
            local task_name, params = line:match("^rake (%S+)(%[%S+%])")
            if task_name == nil then
              -- no parameters
              task_name = line:match("^rake (%S+)")
            end
            if task_name ~= nil then
              local param_names = {}
              local args = { subcmd = { type = "string", default = task_name } }
              if params ~= nil then
                for token in string.gmatch(params, "[^,%[%]]+") do
                  table.insert(param_names, token)
                  args[token] = { type = "string", optional = true }
                end
              end
              table.insert(tasks, { task_name = task_name, args = args, param_names = param_names })
            end
          end
        end
        for _, task in ipairs(tasks) do
          table.insert(ret, {
            name = string.format("rake %s", task.task_name),
            priority = 60,
            params = task.args,
            builder = function(parms)
              local param_vals = {}
              for _, param_name in ipairs(task.param_names) do
                if parms[param_name] ~= nil then
                  table.insert(param_vals, parms[param_name])
                end
              end
              local p = ""
              if #param_vals > 0 then
                p = "[" .. table.concat(param_vals, ",") .. "]"
              end
              local cmd = { "rake", task.task_name .. p }
              return {
                cmd = cmd,
              }
            end,
          })
        end
      end),
      on_exit = vim.schedule_wrap(function(j, output)
        cb(ret)
      end),
    })
    if jid == 0 then
      log:error("Passed invalid arguments to 'rake'")
      cb(ret)
    elseif jid == -1 then
      log:error("'rake' is not executable")
      cb(ret)
    end
  end,
}
