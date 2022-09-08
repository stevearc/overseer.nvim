local constants = require("overseer.constants")
local files = require("overseer.files")
local overseer = require("overseer")
local TAG = constants.TAG

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    args = { type = "list", delimiter = " " },
  },
  builder = function(params)
    local cmd = { "cargo" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
      default_component_params = {
        errorformat = [[%Eerror: %\%%(aborting %\|could not compile%\)%\@!%m,]]
          .. [[%Eerror[E%n]: %m,]]
          .. [[%Inote: %m,]]
          .. [[%Wwarning: %\%%(%.%# warning%\)%\@!%m,]]
          .. [[%C %#--> %f:%l:%c,]]
          .. [[%E  left:%m,%C right:%m %f:%l:%c,%Z,]]
          .. [[%.%#panicked at \'%m\'\, %f:%l:%c]],
      },
    }
  end,
}

return {
  condition = {
    callback = function(opts)
      return files.exists(vim.fn.findfile("Cargo.toml", opts.dir .. ";"))
    end,
  },
  generator = function(opts)
    local commands = {
      { args = { "build" }, tags = { TAG.BUILD } },
      { args = { "test" }, tags = { TAG.TEST } },
      { args = { "check" } },
      { args = { "doc" } },
      { args = { "clean" } },
      { args = { "bench" } },
      { args = { "update" } },
      { args = { "publish" } },
      { args = { "run" } },
    }
    local ret = {}
    for _, command in ipairs(commands) do
      table.insert(
        ret,
        overseer.wrap_template(
          tmpl,
          { name = string.format("cargo %s", table.concat(command.args, " ")), tags = command.tags },
          { args = command.args }
        )
      )
    end
    table.insert(ret, overseer.wrap_template(tmpl, { name = "cargo" }))
    return ret
  end,
}
