local M = {}

local registry = {}
local aliases = {}

local builtin_modules = { "cleanup", "notify", "rerun", "result" }
M.register_all = function()
  for _, mod in ipairs(builtin_modules) do
    require(string.format("overseer.component.%s", mod)).register_all()
  end
end

M.register = function(opts)
  vim.validate({
    name = { opts.name, "s" },
    slot = { opts.name, "s", true },
    description = { opts.description, "s", true },
    builder = { opts.builder, "f" },
    params = { opts.params, "t", true },
  })
  if opts.params then
    for _, param in pairs(opts.params) do
      vim.validate({
        name = { param.name, "s", true },
        description = { param.description, "s", true },
        optional = { param.optional, "b", true },
      })
    end
  end

  registry[opts.name] = opts
end

M.alias = function(name, components)
  vim.validate({
    name = { name, "s" },
    components = { components, "t" },
  })

  aliases[name] = components
end

local function resolve(seen, resolved, names)
  for _, name in ipairs(names) do
    -- Let's not get stuck if there are cycles
    if not seen[name] then
      seen[name] = true
      if aliases[name] then
        resolve(seen, resolved, aliases[name])
      else
        table.insert(resolved, name)
      end
    end
  end
  return resolved
end

local function instantiate(name, component)
  local obj = component.builder()
  obj.name = name
  obj.description = component.description
  obj.slot = component.slot
  return obj
end

M.resolve = function(components, existing)
  vim.validate({
    components = { components, "t" },
    existing = { existing, "t", true },
  })
  local seen = {}
  if existing then
    for _, v in ipairs(M.resolve(existing)) do
      seen[v] = true
    end
  end
  return resolve(seen, {}, components)
end

-- Returns a list of instantiated components
M.load = function(components)
  local resolved = resolve({}, {}, components)
  local ret = {}
  for _, name in ipairs(resolved) do
    local comp = registry[name]
    if comp then
      table.insert(ret, instantiate(name, comp))
    else
      error(string.format("Unknown component '%s'", name))
    end
  end

  return ret
end

return M
