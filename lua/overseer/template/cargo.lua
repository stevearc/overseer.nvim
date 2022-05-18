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
    }
  end,
}

return {
  condition = {
    callback = function(opts)
      return files.exists(files.join(opts.dir, "Cargo.toml"))
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
