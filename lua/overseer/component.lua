local form = require("overseer.form")
local M = {}

-- Canonical naming scheme
-- generally <event>_* means "triggers <event> under some condition"
-- and on_<event>_* means "does something when <event> is fired

local registry = {}
local aliases = {}

local builtin_modules = { "cleanup", "notify", "rerun", "result", "summary" }

M.is_component = function(obj)
  if type(obj) ~= "table" then
    return false
  end
  if obj._type == "OverseerComponent" then
    return true
  end
  if obj.name and obj.constructor then
    return true
  end
  return false
end

M.register_module = function(path)
  local mod = require(path)
  for _, v in pairs(mod) do
    if M.is_component(v) then
      M.register(v)
    end
  end
end

M.register_builtin = function()
  for _, mod in ipairs(builtin_modules) do
    M.register_module(string.format("overseer.component.%s", mod))
  end
end

M.register = function(opts)
  vim.validate({
    name = { opts.name, "s" },
    description = { opts.description, "s", true },
    params = { opts.params, "t", true },
    constructor = { opts.constructor, "f" },
  })
  if opts.name:match("%s") then
    error("Component name cannot have whitespace")
  end
  opts._type = "OverseerComponent"
  if opts.params then
    for name, param in pairs(opts.params) do
      vim.validate({
        description = { param.description, "s", true },
        optional = { param.optional, "b", true },
        type = { param.type, "s", true },
        -- default = any type
      })
      if name:match("%s") then
        error(string.format("Component %s param %s cannot have whitespace", opts.name, name))
      end
    end
  else
    opts.params = {}
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

M.get = function(name)
  return registry[name]
end

M.get_alias = function(name)
  return aliases[name]
end

local function getname(comp_params)
  if type(comp_params) == "string" then
    return comp_params
  else
    local name = comp_params[1]
    if not name then
      -- We store these as json, and when we load them again the indexes are
      -- converted to strings
      name = comp_params["1"]
      comp_params[1] = name
      comp_params["1"] = nil
    end
    return name
  end
end

M.stringify_alias = function(name)
  local strings = {}
  for _, comp in ipairs(aliases[name]) do
    table.insert(strings, getname(comp))
  end
  return table.concat(strings, ", ")
end

M.list = function()
  return vim.tbl_keys(registry)
end

M.list_aliases = function()
  return vim.tbl_keys(aliases)
end

M.params_should_replace = function(new_params, existing)
  for k, v in pairs(new_params) do
    if existing[k] ~= v then
      return true
    end
  end
  return false
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
    local value = params[name]
    if value == nil then
      if opts.default ~= nil then
        params[name] = opts.default
      elseif not opts.optional then
        error(string.format("Component '%s' requires param '%s'", getname(params), name))
      end
    elseif not form.validate_field(opts, value) then
      error(string.format("Component '%s' param '%s' is invalid", getname(params), name))
    end
  end
  for name in pairs(params) do
    if type(name) == "string" and schema[name] == nil then
      vim.notify(
        string.format("Component '%s' passed unknown param '%s'", getname(params), name),
        vim.log.levels.WARN
      )
      params[name] = nil
    end
  end
end

M.create_params = function(name)
  local comp = M.get(name)
  local params = { name }
  validate_params(params, comp.params)
  return params
end

local function instantiate(comp_params, component)
  local obj
  if type(comp_params) == "string" then
    comp_params = { comp_params }
  end
  validate_params(comp_params, component.params)
  obj = component.constructor(comp_params)
  obj.name = getname(comp_params)
  obj.params = comp_params
  obj.description = component.description
  return obj
end

-- @param components is a list of component names or {name, params=}
-- @param existing is a list of instantiated components or component params
M.resolve = function(components, existing)
  vim.validate({
    components = { components, "t" },
    existing = { existing, "t", true },
  })
  local seen = {}
  if existing then
    for _, comp in ipairs(existing) do
      local name = getname(comp)
      if not name then
        name = comp.name
      end
      seen[name] = true
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
