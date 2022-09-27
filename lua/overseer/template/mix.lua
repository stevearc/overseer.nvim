local files = require("overseer.files")
local overseer = require("overseer")
local log = require("overseer.log")

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { optional = true, type = "list", delimiter = " " },
  },
  builder = function(params)
    local cmd = { "mix" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

return {
  condition = {
    callback = function(opts)
      return files.exists(files.join(opts.dir, "mix.exs"))
    end,
  },
  generator = function(opts, cb)
    local ret = {}
    local jid = vim.fn.jobstart({
      "mix",
      "help",
    }, {
      cwd = opts.dir,
      stdout_buffered = true,
      on_stdout = vim.schedule_wrap(function(j, output)
        for _, line in ipairs(output) do
          local task_name = line:match("mix (%S+)%s")
          table.insert(
            ret,
            overseer.wrap_template(
              tmpl,
              { name = string.format("mix %s", task_name) },
              { args = { task_name } }
            )
          )
        end
      end),
      on_exit = vim.schedule_wrap(function(j, output)
        cb(ret)
      end),
    })
    if jid == 0 then
      log:error("Passed invalid arguments to 'mix'")
      cb(ret)
    elseif jid == -1 then
      log:error("'mix' is not executable")
      cb(ret)
    end
  end,
}
