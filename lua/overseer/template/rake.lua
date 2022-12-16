local files = require("overseer.files")
local log = require("overseer.log")

return {
  cache_key = function(opts)
    return vim.fn.fnamemodify(vim.fn.findfile("Rakefile", opts.dir .. ";"), ":p")
  end,
  condition = {
    callback = function(opts)
      if not files.exists(files.join(opts.dir, "Rakefile")) then
        return false, "No Rakefile file found"
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
            local _, _, task_name, params = string.find(line, "^rake (%S+)(%[%S+%])")
            if task_name == nil then
              -- no parameters
              local _, _, task_name_no_params = string.find(line, "^rake (%S+)")
              task_name = task_name_no_params
            end
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
        for _, task in ipairs(tasks) do
          table.insert(ret, {
            name = string.format("rake %s", task.task_name),
            priority = 60,
            params = task.args,
            builder = function(parms)
              local p = ""
              if
                #vim.tbl_filter(function(p_n)
                  return parms[p_n] ~= nil
                end, task.param_names) > 0
              then
                p = "["
                for _, param_name in ipairs(task.param_names) do
                  if parms[param_name] ~= nil then
                    if #p > 1 then
                      p = p .. ","
                    end
                    p = p .. parms[param_name]
                  end
                end
                p = p .. "]"
              else
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
