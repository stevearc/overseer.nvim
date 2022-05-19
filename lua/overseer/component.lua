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

local function getname(comp_params)
  if type(comp_params) == "string" then
    return comp_params
  else
    return comp_params[1]
  end
end

local function resolve(seen, resolved, names)
  for _, comp_params in ipairs(names) do
    local name = getname(comp_params)
    -- Let's not get stuck if there are cycles
    if not seen[name] then
      seen[name] = true
      if aliases[name] then
        resolve(seen, resolved, aliases[name])
      else
        table.insert(resolved, comp_params)
      end
    end
  end
  return resolved
end

local function validate_params(params, schema)
  for name, opts in pairs(schema) do
    if params[name] == nil and not opts.optional then
      error(string.format("Component '%s' requires param '%s'", getname(params), name))
    end
  end
  for name in pairs(params) do
    if type(name) == "string" and schema[name] == nil then
      vim.notify(
        string.format("Component '%s' passed unknown param '%s'", getname(params), name),
        vim.log.levels.WARN
      )
    end
  end
end

local function instantiate(comp_params, component)
  local obj
  if type(comp_params) == "string" then
    obj = component.builder()
  else
    validate_params(comp_params, component.params)
    obj = component.builder(comp_params)
  end
  obj.name = getname(comp_params)
  obj.params = comp_params
  obj.description = component.description
  obj.slot = component.slot
  return obj
end

-- @param components is a list of component names or {name, params=}
-- @param existing is a list of instantiated components
M.resolve = function(components, existing)
  vim.validate({
    components = { components, "t" },
    existing = { existing, "t", true },
  })
  local seen = {}
  if existing then
    for _, comp in ipairs(existing) do
      seen[comp.name] = true
    end
  end
  return resolve(seen, {}, components)
end

-- @param components is a list of component names or {name, params=}
-- @returns a list of instantiated components
M.load = function(components)
  local resolved = resolve({}, {}, components)
  local ret = {}
  for _, comp_params in ipairs(resolved) do
    local name = getname(comp_params)
    local comp = registry[name]
    if comp then
      table.insert(ret, instantiate(comp_params, comp))
    else
      error(string.format("Unknown component '%s'", name))
    end
  end

  return ret
end

return M
