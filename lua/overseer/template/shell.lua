---@type overseer.TemplateDefinition
local tmpl = {
  name = "shell",
  params = {
    cmd = { type = "string" },
    env = { type = "opaque", optional = true },
    cwd = { type = "string", optional = true },
    name = { type = "string", optional = true },
    metadata = { type = "opaque", optional = true },
    expand_cmd = {
      desc = "Run expandcmd() on command before execution",
      type = "boolean",
      default = true,
      optional = true,
    },
  },
  builder = function(params)
    local cmd = params.expand_cmd and vim.fn.expandcmd(params.cmd) or params.cmd
    return {
      cmd = cmd,
      env = params.env,
      cwd = params.cwd,
      name = params.name,
      metadata = params.metadata,
    }
  end,
}

return tmpl
