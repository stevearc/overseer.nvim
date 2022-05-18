local Template = {}

function Template.new(opts)
  opts = opts or {}
  vim.validate({
    name = { opts.name, "s" },
    builder = { opts.builder, "f" },
    params = { opts.params, "t" },
  })
  for _, param in pairs(opts.params) do
    vim.validate({
      name = { param.name, "s" },
      description = { param.description, "s" },
      optional = { param.optional, "b", true },
    })
  end
  return setmetatable(opts, { __index = Template })
end

function Template:build(params)
  for k, config in pairs(self.params) do
    if params[k] == nil and not config.optional then
      error(string.format("Missing param %s", k))
    end
  end
  return self.builder(params)
end

function Template:prompt(params, callback)
  vim.validate({
    params = { params, "t" },
    callback = { callback, "f" },
  })
  print("TODO")
end

return Template
