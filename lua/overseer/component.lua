local config = require("overseer.config")
local form_utils = require("overseer.form.utils")
local log = require("overseer.log")
local util = require("overseer.util")
local M = {}

---Definition used to instantiate a Component
---The canonical naming scheme is as follows:
---`<event>_*` means "triggers <event> under some condition"
---`on_<event>_*` means "does something when <event> is fired
---@class overseer.ComponentFileDefinition
---@field desc string description of component
---@field long_desc? string extended description for documentation generation
---@field params? overseer.Params parameters that can customize the component
---@field constructor fun(params: table): overseer.ComponentSkeleton creates the component from the params
---@field editable? boolean when true, component can be live-edited in the task editor
---@field serializable? boolean when true, will be serialized when serializing a task
---@field deprecated_message? string when present, overseer will warn the user when this component is used

---@class overseer.ComponentDefinition : overseer.ComponentFileDefinition
---@field name string

---The intermediate form of a component returned by the constructor
---@class overseer.ComponentSkeleton
---@field on_init? fun(self: overseer.Component, task: overseer.Task) called when the component is first created.
---@field on_pre_start? fun(self: overseer.Component, task: overseer.Task): nil|boolean called when a task is attempting to start. Can return false to prevent the task from starting.
---@field on_start? fun(self: overseer.Component, task: overseer.Task) called when the task has started
---@field on_reset? fun(self: overseer.Component, task: overseer.Task) called when the task is reset
---@field on_pre_result? fun(self: overseer.Component, task: overseer.Task): nil|table called when the task is generating results. Can return a table that will be merged into the task's results.
---@field on_preprocess_result? fun(self: overseer.Component, task: overseer.Task, result: table) called after on_pre_result and before on_result. Can modify the result table.
---@field on_result? fun(self: overseer.Component, task: overseer.Task, result: table) called after the task result has been created
---@field on_complete? fun(self: overseer.Component, task: overseer.Task, status: overseer.Status, result: table) called when the task completes (successful or not)
---@field on_output? fun(self: overseer.Component, task: overseer.Task, data: string[]) called with the raw output from jobstart on_stdout callback
---@field on_output_lines? fun(self: overseer.Component, task: overseer.Task, lines: string[]) called with lines of text from the output. This is easier to work with than the raw data from on_output.
---@field on_exit? fun(self: overseer.Component, task: overseer.Task, code: number) called when the process exits
---@field on_dispose? fun(self: overseer.Component, task: overseer.Task) called when the task is disposed or the component is removed. Guaranteed to be called if on_init was called.
---@field on_status? fun(self: overseer.Component, task: overseer.Task, status: overseer.Status) Called when the task status changes
---@field render? fun(self: overseer.Component, task: overseer.Task, lines: string[], highlights: table[], detail: number)

---An instantiated component that is attached to a Task
---@class overseer.Component : overseer.ComponentSkeleton
---@field name string
---@field params table
---@field desc? string
---@field serializable boolean
---@field editable boolean

local registry = {}

local builtin_components = {
  "dependencies",
  "display_duration",
  "on_complete_dispose",
  "on_complete_notify",
  "on_complete_restart",
  "on_exit_set_status",
  "on_output_parse",
  "on_output_quickfix",
  "on_output_summarize",
  "on_output_write_file",
  "on_result_diagnostics",
  "on_result_diagnostics_quickfix",
  "on_result_diagnostics_trouble",
  "on_result_notify",
  "open_output",
  "restart_on_save",
  "run_after",
  "timeout",
  "unique",
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
    serializable = { opts.serializable, "b", true },
  })
  ---@type overseer.Component
  local comp = vim.deepcopy(opts) ---@diagnostic disable-line: assign-type-mismatch
  if comp.serializable == nil then
    comp.serializable = true
  end
  if name:match("%s") then
    error("Component name cannot have whitespace")
  end
  if comp.params then
    form_utils.validate_params(comp.params)
    for _, param in pairs(comp.params) do
      -- Default editable = false if any types are opaque
      if param.type == "opaque" and comp.editable == nil then
        comp.editable = false
      end
    end
  else
    comp.params = {}
  end
  if comp.editable == nil then
    comp.editable = true
  end
  comp.name = name
  if opts.deprecated_message then
    vim.notify_once(
      string.format("Overseer component %s is deprecated: %s", name, opts.deprecated_message),
      vim.log.levels.WARN
    )
  end
  return comp
end

---@param name string
---@param components string[]
M.alias = function(name, components)
  config.component_aliases[name] = components
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
  return config.component_aliases[name]
end

---@param comp_params overseer.Serialized
---@return string
local function getname(comp_params)
  local name = util.split_config(comp_params)
  return name
end

---@param name string
---@return string
M.stringify_alias = function(name)
  local strings = {}
  for _, comp in ipairs(M.get_alias(name) or {}) do
    table.insert(strings, getname(comp))
  end
  return table.concat(strings, ", ")
end

local preloaded = false
local function preload_components()
  if preloaded then
    return
  end
  preloaded = true
  local comp_files = vim.api.nvim_get_runtime_file("lua/overseer/component/*.lua", true)
  for _, abspath in ipairs(comp_files) do
    local module_name = abspath:match("^.*overseer/component/(.*)%.lua$")
    M.get(module_name)
  end
end

---@return string[]
M.list_editable = function()
  local ret = {}
  preload_components()
  for k, v in pairs(registry) do
    if v.editable then
      table.insert(ret, k)
    end
  end
  return ret
end

---@return string[]
M.list_aliases = function()
  return vim.tbl_keys(config.component_aliases)
end

M.params_should_replace = function(new_params, existing)
  for k, v in pairs(new_params) do
    if existing[k] ~= v then
      return true
    end
  end
  return false
end

---@param seen table<string, boolean>
---@param resolved overseer.Serialized[]
---@param names overseer.Serialized[]
---@return overseer.Serialized[]
local function resolve(seen, resolved, names)
  for _, comp_params in ipairs(names) do
    local name = getname(comp_params)
    -- Let's not get stuck if there are cycles
    if not seen[name] then
      seen[name] = true
      local alias_components = M.get_alias(name)
      if alias_components then
        resolve(seen, resolved, alias_components)
      else
        table.insert(resolved, comp_params)
      end
    end
  end
  return resolved
end

---@param params table
---@param schema? table
---@param ignore_errors? boolean
local function validate_params(params, schema, ignore_errors)
  if schema then
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
      elseif not form_utils.validate_field(opts, value) then
        if not ignore_errors then
          error(string.format("Component '%s' param '%s' is invalid", getname(params), name))
        end
      end
    end
  end
  for name in pairs(params) do
    if type(name) == "string" and (not schema or schema[name] == nil) then
      log.warn("Component '%s' passed unknown param '%s'", getname(params), name)
      params[name] = nil
    end
  end
end

---@param name string
---@return table
M.create_default_params = function(name)
  local comp = assert(M.get(name))
  local params = { name }
  validate_params(params, comp.params, true)
  return params
end

---@param comp_params overseer.Serialized
---@param component overseer.ComponentDefinition
---@param default_params table default params for components
---@return overseer.Component
local function instantiate(comp_params, component, default_params)
  local obj
  if type(comp_params) == "string" then
    comp_params = { comp_params }
  end
  -- Merge in the default params from the task for any param with default_from_task = true
  for k, v in pairs(component.params) do
    if v.default_from_task and comp_params[k] == nil then
      comp_params[k] = default_params[k]
    end
  end
  validate_params(comp_params, component.params)
  ---@type overseer.Component
  obj = component.constructor(comp_params)
  obj.name = getname(comp_params)
  obj.params = comp_params
  obj.desc = component.desc
  obj.serializable = component.serializable
  return obj
end

---@param components overseer.Serialized[] A list of component names or {name, params=}
---@param existing nil|overseer.Serialized[] A list of instantiated components or component params
---@return overseer.Serialized[]
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

---@param components overseer.Serialized[] is a list of component names or {name, params=}
---@param default_params table default params for components
---@return overseer.Component[]
M.load = function(components, default_params)
  local resolved = resolve({}, {}, components)
  local ret = {}
  for _, comp_params in ipairs(resolved) do
    local name = getname(comp_params)
    local comp = M.get(name)
    if comp then
      table.insert(ret, instantiate(comp_params, comp, default_params))
    else
      error(string.format("Unknown component '%s'", name))
    end
  end

  return ret
end

local function simplify_param(param)
  return {
    name = param.name,
    desc = param.desc,
    long_desc = param.long_desc,
    optional = param.optional,
    default = param.default,
    type = param.type or "string",
    subtype = param.subtype and simplify_param(param.subtype),
    deprecated = param.deprecated,
    choices = param.choices,
    order = param.order,
  }
end

local function simplify_params(params)
  local ret = {}
  for k, v in pairs(params) do
    ret[k] = simplify_param(v)
  end
  return ret
end

---Used for documentation generation
---@private
M.get_all_descriptions = function()
  local ret = {}
  preload_components()
  local names = vim.tbl_keys(registry)
  table.sort(names)
  for _, name in ipairs(names) do
    local defn = assert(M.get(name))
    table.insert(ret, {
      name = name,
      desc = defn.desc,
      long_desc = defn.long_desc,
      params = simplify_params(defn.params),
    })
  end
  return ret
end

return M
