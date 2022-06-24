local config = require("overseer.config")
local form = require("overseer.form")
local log = require("overseer.log")
local M = {}

---Definition used to instantiate a Component
---The canonical naming scheme is as follows:
---`<event>_*` means "triggers <event> under some condition"
---`on_<event>_*` means "does something when <event> is fired
---@class overseer.ComponentDefinition
---@field name? string
---@field desc string
---@field params? overseer.Params
---@field editable? boolean
---@field serialize? "exclude"|"fail"
---@field constructor fun(params: table): overseer.ComponentSkeleton

---The intermediate form of a component returned by the constructor
---@class overseer.ComponentSkeleton
---@field on_init? fun(self: overseer.Component, task: overseer.Task)
---@field on_start? fun(self: overseer.Component, task: overseer.Task)
---@field on_reset? fun(self: overseer.Component, task: overseer.Task, soft: boolean)
---@field on_result? fun(self: overseer.Component, task: overseer.Task, status: overseer.Status, result: table)
---@field on_complete? fun(self: overseer.Component, task: overseer.Task, status: overseer.Status, result: table)
---@field on_output? fun(self: overseer.Component, task: overseer.Task, data: string[])
---@field on_output_lines? fun(self: overseer.Component, task: overseer.Task, lines: string[])
---@field on_request_restart? fun(self: overseer.Component, task: overseer.Task)
---@field on_exit? fun(self: overseer.Component, task: overseer.Task, code: number)
---@field on_dispose? fun(self: overseer.Component, task: overseer.Task)
---@field render? fun(self: overseer.Component, task: overseer.Task, lines: string[], highlights: table[], detail: number)

---An instantiated component that is attached to a Task
---@class overseer.Component : overseer.ComponentSkeleton
---@field name string
---@field params table
---@field desc? string
---@field serialize? "exclude"|"fail"

local registry = {}
local aliases = {}

local builtin_components = {
  "on_output_summarize",
  "on_output_write_file",
  "on_restart_handler",
  "on_result_diagnostics",
  "on_result_diagnostics_quickfix",
  "on_result_notify",
  "on_result_notify_red_green",
  "on_result_notify_system",
  "on_result_restart",
  "on_status_run_task",
  "restart_on_save",
  "result_exit_code",
  "timeout",
}

---@param name string
---@param opts overseer.ComponentDefinition
---@return overseer.Component
local function validate_component(name, opts)
  vim.validate({
    desc = { opts.desc, "s", true },
    params = { opts.params, "t", true },
    constructor = { opts.constructor, "f" },
    editable = { opts.editable, "b", true },
    serialize = { opts.serialize, "s", true }, -- 'exclude' or 'fail'
  })
  if name:match("%s") then
    error("Component name cannot have whitespace")
  end
  opts._type = "OverseerComponent"
  if opts.params then
    form.validate_params(opts.params)
    for _, param in pairs(opts.params) do
      -- Default editable = false if any types are opaque
      if param.type == "opaque" and opts.editable == nil then
        opts.editable = false
      end
    end
  else
    opts.params = {}
  end
  if opts.editable == nil then
    opts.editable = true
  end
  opts.name = name
  return opts
end

---@param name string
---@param components string[]
M.alias = function(name, components)
  vim.validate({
    name = { name, "s" },
    components = { components, "t" },
  })

  aliases[name] = components
end

---@param name string
---@return overseer.ComponentDefinition?
M.get = function(name)
  if not registry[name] then
    local ok, mod = pcall(require, string.format("overseer.component.%s", name))
    if ok then
      registry[name] = validate_component(name, mod)
    end
  end
  return registry[name]
end

---@param name string
---@return string[]?
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

---@param name string
---@return string
M.stringify_alias = function(name)
  local strings = {}
  for _, comp in ipairs(aliases[name]) do
    table.insert(strings, getname(comp))
  end
  return table.concat(strings, ", ")
end

---@return string[]
M.list_editable = function()
  local ret = {}
  for _, v in ipairs(config.preload_components) do
    M.get(v)
  end
  for _, v in ipairs(builtin_components) do
    M.get(v)
  end
  for k, v in pairs(registry) do
    if v.editable then
      table.insert(ret, k)
    end
  end
  return ret
end

---@return string[]
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

local function validate_params(params, schema, ignore_errors)
  for name, opts in pairs(schema) do
    local value = params[name]
    if value == nil then
      if opts.default ~= nil then
        params[name] = opts.default
      elseif not opts.optional then
        if not ignore_errors then
          error(string.format("Component '%s' requires param '%s'", getname(params), name))
        end
      end
    elseif not form.validate_field(opts, value) then
      if not ignore_errors then
        error(string.format("Component '%s' param '%s' is invalid", getname(params), name))
      end
    end
  end
  for name in pairs(params) do
    if type(name) == "string" and schema[name] == nil then
      log:warn("Component '%s' passed unknown param '%s'", getname(params), name)
      params[name] = nil
    end
  end
end

---@param name string
---@return table
M.create_params = function(name)
  local comp = M.get(name)
  local params = { name }
  validate_params(params, comp.params, true)
  return params
end

---@param component overseer.ComponentDefinition
---@return overseer.Component
local function instantiate(comp_params, component)
  local obj
  if type(comp_params) == "string" then
    comp_params = { comp_params }
  end
  validate_params(comp_params, component.params)
  obj = component.constructor(comp_params)
  obj.name = getname(comp_params)
  obj.params = comp_params
  obj.desc = component.desc
  obj.serialize = component.serialize
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
---@return overseer.Component[]
M.load = function(components)
  local resolved = resolve({}, {}, components)
  local ret = {}
  for _, comp_params in ipairs(resolved) do
    local name = getname(comp_params)
    local comp = M.get(name)
    if comp then
      table.insert(ret, instantiate(comp_params, comp))
    else
      error(string.format("Unknown component '%s'", name))
    end
  end

  return ret
end

local function simplify_params(params)
  local ret = {}
  for k, v in pairs(params) do
    ret[k] = {
      name = v.name,
      desc = v.desc,
      optional = v.optional,
      default = v.default,
      type = v.type or "string",
    }
  end
  return ret
end

M.get_all_descriptions = function()
  local ret = {}
  for _, name in ipairs(builtin_components) do
    local defn = M.get(name)
    table.insert(ret, {
      name = name,
      desc = defn.desc,
      params = simplify_params(defn.params),
    })
  end
  return ret
end

return M
