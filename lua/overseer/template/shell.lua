---@type overseer.TemplateDefinition
local tmpl = {
  name = "shell",
  params = {
    cmd = { type = "string" },
    env = { type = "opaque", optional = true },
    cwd = { type = "string", optional = true },
    name = { type = "string", optional = true },
    metadata = { type = "opaque", optional = true },
  },
  builder = function(params)
    return {
      cmd = params.cmd,
      env = params.env,
      cwd = params.cwd,
      name = params.name,
      metadata = params.metadata,
    }
  end,
}

return tmpl
