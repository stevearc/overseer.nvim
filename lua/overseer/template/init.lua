local config = require("overseer.config")
local files = require("overseer.files")
local form = require("overseer.form")
local log = require("overseer.log")
local Task = require("overseer.task")
local task_builder = require("overseer.task_builder")
local util = require("overseer.util")
local M = {}

---@class overseer.TemplateProvider
---@field name string
---@field condition? overseer.SearchCondition
---@field generator fun(opts: overseer.SearchParams): overseer.TemplateDefinition[]

---@class overseer.TemplateDefinition
---@field name string
---@field desc? string
---@field tags? string[]
---@field params overseer.Params
---@field priority? number
---@field condition? overseer.SearchCondition
---@field builder fun(params: table): overseer.TaskDefinition

---@class overseer.SearchCondition
---@field filetype? string|string[]
---@field dir? string|string[]
---@field callback? fun(search: overseer.SearchParams): boolean

---@alias overseer.Params table<string, overseer.Param>

local DEFAULT_PRIORITY = 50

---@type table<string, overseer.TemplateDefinition>
local registry = {}

---@type overseer.TemplateProvider[]
local providers = {}

---@param condition? overseer.SearchCondition
---@param tags? string[]
---@param search overseer.SearchParams
local function condition_matches(condition, tags, search)
  if not condition then
    return true
  end
  if condition.filetype then
    if type(condition.filetype) == "string" then
      if condition.filetype ~= search.filetype then
        return false
      end
    elseif not vim.tbl_contains(condition.filetype, search.filetype) then
      return false
    end
  end

  if condition.dir then
    if type(condition.dir) == "string" then
      if not files.is_subpath(condition.dir, search.dir) then
        return false
      end
    elseif
      not util.list_any(condition.dir, function(d)
        return files.is_subpath(d, search.dir)
      end)
    then
      return false
    end
  end

  if search.tags and not vim.tbl_isempty(search.tags) then
    if not tags then
      return false
    end
    local tag_map = util.list_to_map(tags)
    for _, v in ipairs(search.tags) do
      if not tag_map[v] then
        return false
      end
    end
  end

  if condition.callback then
    if not condition.callback(search) then
      return false
    end
  end
  return true
end

local function load_template(name)
  local ok, defn = pcall(require, string.format("overseer.template.%s", name))
  if not ok then
    log:error("Error loading template '%s': %s", name, defn)
    return
  end
  -- If this module was just a list of names, then it's an alias for a
  -- collection of templates
  if vim.tbl_islist(defn) then
    for _, v in ipairs(defn) do
      load_template(v)
    end
  else
    if not defn.name then
      defn.name = name
    end
    M.register(defn)
  end
end

local initialized = false
local function initialize()
  if initialized then
    return
  end
  for _, name in ipairs(config.templates) do
    load_template(name)
  end
  initialized = true
end

---@param defn overseer.TemplateDefinition
local function validate_template_definition(defn)
  defn.priority = defn.priority or DEFAULT_PRIORITY
  vim.validate({
    name = { defn.name, "s" },
    desc = { defn.desc, "s", true },
    tags = { defn.tags, "t", true },
    params = { defn.params, "t" },
    priority = { defn.priority, "n" },
    builder = { defn.builder, "f" },
  })
  form.validate_params(defn.params)
end

---@param defn overseer.TemplateDefinition|overseer.TemplateProvider
M.register = function(defn)
  if defn.generator then
    table.insert(providers, defn)
  else
    validate_template_definition(defn)
    registry[defn.name] = defn
  end
end

---@param tmpl overseer.TemplateDefinition
---@param prompt "always"|"never"|"allow"|"missing"
---@param params table
---@param callback fun(task: overseer.Task|nil)
M.build = function(tmpl, prompt, params, callback)
  local any_missing = false
  local required_missing = false
  for k, schema in pairs(tmpl.params) do
    if params[k] == nil then
      if schema.default ~= nil then
        params[k] = schema.default
      else
        if prompt == "never" then
          error(string.format("Missing param %s", k))
        end
        any_missing = true
        if not schema.optional then
          required_missing = true
        end
        break
      end
    end
  end

  if
    prompt == "never"
    or (prompt == "allow" and not required_missing)
    or (prompt == "missing" and not any_missing)
    or vim.tbl_isempty(tmpl.params)
  then
    callback(Task.new(tmpl.builder(params)))
    return
  end

  local schema = {}
  for k, v in pairs(tmpl.params) do
    schema[k] = v
  end
  task_builder.open(tmpl.name, schema, params, function(final_params)
    if final_params then
      callback(Task.new(tmpl.builder(final_params)))
    else
      callback()
    end
  end)
end

---@param base overseer.TemplateDefinition
---@param override? table
---@param default_params? table
---@return overseer.TemplateDefinition
M.wrap = function(base, override, default_params)
  override = override or {}
  if default_params then
    override.builder = function(_, params)
      params = params or {}
      for k, v in pairs(default_params) do
        params[k] = v
      end
      return base.builder(params)
    end
  end
  return setmetatable(override, { __index = base })
end

---@class overseer.SearchParams
---@field filetype? string
---@field tags? string[]
---@field dir string

---@param opts? overseer.SearchParams
---@return overseer.TemplateDefinition[]
M.list = function(opts)
  initialize()
  opts = opts or {}
  vim.validate({
    tags = { opts.tags, "t", true },
    dir = { opts.dir, "s" },
    filetype = { opts.filetype, "s", true },
  })
  local ret = {}
  for _, tmpl in pairs(registry) do
    if condition_matches(tmpl.condition, tmpl.tags, opts) then
      table.insert(ret, tmpl)
    end
  end

  for _, provider in ipairs(providers) do
    if condition_matches(provider.condition, nil, opts) then
      local ok, tmpls = pcall(provider.generator, opts)
      if ok then
        for _, tmpl in ipairs(tmpls) do
          validate_template_definition(tmpl)
          if condition_matches(tmpl.condition, tmpl.tags, opts) then
            table.insert(ret, tmpl)
          end
        end
      else
        log:error("Template provider %s: %s", provider.name, tmpls)
      end
    end
  end

  table.sort(ret, function(a, b)
    if a.priority == b.priority then
      return a.name < b.name
    else
      return a.priority < b.priority
    end
  end)

  return ret
end

---@param name string
---@param opts? overseer.SearchParams
---@return overseer.TemplateDefinition?
M.get_by_name = function(name, opts)
  initialize()
  local ret = registry[name]
  if ret then
    return ret
  end
  for _, tmpl in ipairs(M.list(opts)) do
    if tmpl.name == name then
      return tmpl
    end
  end
end

return M
