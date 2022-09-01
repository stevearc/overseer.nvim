local component = require("overseer.component")
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
---@field aliases? string[]
---@field desc? string
---@field tags? string[]
---@field params? overseer.Params
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
---@param match_tags boolean
local function condition_matches(condition, tags, search, match_tags)
  if not condition then
    return true
  end
  if condition.filetype then
    local search_fts = vim.split(search.filetype, ".", true)
    local any_ft_match = false
    for _, ft in util.iter_as_list(condition.filetype) do
      if vim.tbl_contains(search_fts, ft) then
        any_ft_match = true
        break
      end
    end
    if not any_ft_match then
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

  if match_tags and search.tags and not vim.tbl_isempty(search.tags) then
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

---@param name string
M.load_template = function(name)
  local ok, defn = pcall(require, string.format("overseer.template.%s", name))
  if not ok then
    log:error("Error loading template '%s': %s", name, defn)
    return
  end
  -- If this module was just a list of names, then it's an alias for a
  -- collection of templates
  if vim.tbl_islist(defn) then
    for _, v in ipairs(defn) do
      M.load_template(v)
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
    M.load_template(name)
  end
  initialized = true
end

---@param defn overseer.TemplateDefinition
local function validate_template_definition(defn)
  defn.priority = defn.priority or DEFAULT_PRIORITY
  defn.params = defn.params or {}
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

---@class overseer.TaskUtil
local task_util = {}
---@param task_defn overseer.TaskDefinition
---@param ... overseer.Serialized
function task_util.add_component(task_defn, ...)
  local names = vim.tbl_map(util.split_config, { ... })
  task_util.remove_component(task_defn, names)
  vim.list_extend(task_defn.components, { ... })
end
---@param task_defn overseer.TaskDefinition
---@param ... string
function task_util.remove_component(task_defn, ...)
  local to_remove = util.list_to_map({ ... })
  task_defn.components = vim.tbl_filter(function(comp)
    return not to_remove[util.split_config(comp)]
  end, task_defn.components)
end
---@param task_defn overseer.TaskDefinition
---@param name string
---@return boolean
function task_util.has_component(task_defn, name)
  for _, comp in ipairs(task_defn.components) do
    if name == util.split_config(comp) then
      return true
    end
  end
  return false
end

---@param tmpl overseer.TemplateDefinition
---@param params table
---@param opts overseer.TemplateBuildOpts
---@return overseer.Task
local function build_task(tmpl, opts, params)
  local task_defn = tmpl.builder(params)
  task_defn.components = component.resolve(task_defn.components or { "default" })
  config.pre_task_hook(task_defn, task_util)
  if opts.cwd then
    task_defn.cwd = opts.cwd
  end
  if task_defn.env or opts.env then
    task_defn.env = vim.tbl_deep_extend("force", task_defn.env or {}, opts.env or {})
  end
  local task = Task.new(task_defn)
  return task
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

---@class overseer.TemplateBuildOpts
---@field prompt "always"|"never"|"allow"|"missing"
---@field params table
---@field cwd? string
---@field env? table<string, string>

---@param tmpl overseer.TemplateDefinition
---@param opts overseer.TemplateBuildOpts
---@param callback fun(task: overseer.Task|nil, err: string|nil)
M.build = function(tmpl, opts, callback)
  vim.validate({
    prompt = { opts.prompt, "s" },
    params = { opts.params, "t" },
    cwd = { opts.cwd, "s", true },
    env = { opts.env, "t", true },
  })
  local any_missing = false
  local required_missing = false
  for k, schema in pairs(tmpl.params) do
    if opts.params[k] == nil then
      if schema.default ~= nil then
        opts.params[k] = schema.default
      else
        if opts.prompt == "never" then
          return callback(nil, string.format("Missing param %s", k))
        end
        any_missing = true
        if not schema.optional then
          required_missing = true
          break
        end
      end
    end
  end

  if
    opts.prompt == "never"
    or (opts.prompt == "allow" and not required_missing)
    or (opts.prompt == "missing" and not any_missing)
    or vim.tbl_isempty(tmpl.params)
  then
    callback(build_task(tmpl, opts, opts.params))
    return
  end

  local schema = {}
  for k, v in pairs(tmpl.params) do
    schema[k] = v
  end
  task_builder.open(tmpl.name, schema, opts.params, function(final_params)
    if final_params then
      callback(build_task(tmpl, opts, final_params))
    else
      callback()
    end
  end)
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
    if condition_matches(tmpl.condition, tmpl.tags, opts, true) then
      table.insert(ret, tmpl)
    end
  end

  for _, provider in ipairs(providers) do
    if condition_matches(provider.condition, nil, opts, false) then
      local ok, tmpls = pcall(provider.generator, opts)
      if ok then
        for _, tmpl in ipairs(tmpls) do
          validate_template_definition(tmpl)
          if condition_matches(tmpl.condition, tmpl.tags, opts, true) then
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
    if tmpl.aliases then
      for _, alias in ipairs(tmpl.aliases) do
        if alias == name then
          return tmpl
        end
      end
    end
  end
end

return M
