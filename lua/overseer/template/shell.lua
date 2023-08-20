---@type overseer.TemplateFileDefinition
local tmpl = {
  name = "shell",
  params = {
    cmd = { type = "string", order = 1 },
    name = { type = "string", optional = true, order = 2 },
    cwd = { type = "string", optional = true, order = 4 },
    env = { type = "opaque", optional = true },
    metadata = { type = "opaque", optional = true },
    components = { type = "opaque", optional = true },
    strategy = { type = "opaque", optional = true },
    expand_cmd = {
      desc = "Run expandcmd() on command before execution",
      type = "boolean",
      default = true,
      optional = true,
      order = 3,
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
      components = params.components,
      strategy = params.strategy,
    }
  end,
}

return tmpl
