local M = {}

local registry = {}
local aliases = {}

local builtin_modules = { "notify", "rerun", "result" }
M.register_all = function()
  for _, mod in ipairs(builtin_modules) do
    require(string.format("overseer.capability.%s", mod)).register_all()
  end
end

M.register = function(opts)
  vim.validate({
    name = { opts.name, "s" },
    category = { opts.name, "s" },
    description = { opts.description, "s", true },
    builder = { opts.builder, "f" },
  })

  registry[opts.name] = opts
end

M.alias = function(name, capabilities)
  vim.validate({
    name = { name, "s" },
    capabilities = { capabilities, "t" },
  })

  aliases[name] = capabilities
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

local function instantiate(name, capability)
  local obj = capability.builder()
  obj.name = name
  obj.description = capability.description
  obj.category = capability.category
  return obj
end

M.resolve = function(capabilities, existing)
  vim.validate({
    capabilities = { capabilities, "t" },
    existing = { existing, "t", true },
  })
  local seen = {}
  if existing then
    for _, v in ipairs(M.resolve(existing)) do
      seen[v] = true
    end
  end
  return resolve(seen, {}, capabilities)
end

-- Returns a list of capabilities
M.load = function(capabilities)
  local resolved = resolve({}, {}, capabilities)
  local ret = {}
  for _, name in ipairs(resolved) do
    local cap = registry[name]
    if cap then
      table.insert(ret, instantiate(name, cap))
    else
      error(string.format("Unknown capability '%s'", name))
    end
  end

  return ret
end

return M
