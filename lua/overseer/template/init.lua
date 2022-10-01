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
---@field module? string The name of the module this was loaded from
---@field condition? overseer.SearchCondition
---@field generator fun(opts: overseer.SearchParams, cb: fun(tmpls: overseer.TemplateDefinition[]))

---@class overseer.TemplateDefinition
---@field name string
---@field module? string The name of the module this was loaded from
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

---@type table<string, overseer.TemplateDefinition[]>
local cached_provider_results = {}

---@type nil|integer
local clear_cache_autocmd

local hooks = {}

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

---@param opts? overseer.HookOptions
---@param search overseer.SearchParams
---@param name string
---@param module? string
---@return boolean
local function hook_matches(opts, search, name, module)
  if not opts or vim.tbl_isempty(opts) then
    return true
  end
  if not condition_matches(opts, nil, search, false) then
    return false
  end
  if opts.module then
    if not module or not module:match(opts.module) then
      return false
    end
  end
  if opts.name then
    if not name:match(opts.name) then
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
    defn.module = name
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

---@param defn overseer.TemplateProvider
local function validate_template_provider(defn)
  vim.validate({
    name = { defn.name, "s" },
    generator = { defn.generator, "f" },
    cache_key = { defn.cache_key, "f", true },
  })
  if not defn.cache_key then
    defn.cache_key = function(opts)
      return opts.dir
    end
  end
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
---Add one or more components to a TaskDefinition
---@param task_defn overseer.TaskDefinition
---@param ... overseer.Serialized
function task_util.add_component(task_defn, ...)
  local names = vim.tbl_map(util.split_config, { ... })
  task_util.remove_component(task_defn, names)
  task_defn.components = vim.list_extend({ ... }, task_defn.components or { "default" })
end
---Remove one or more components from a TaskDefinition
---@param task_defn overseer.TaskDefinition
---@param ... string
function task_util.remove_component(task_defn, ...)
  local to_remove = util.list_to_map({ ... })
  task_defn.components = vim.tbl_filter(function(comp)
    return not to_remove[util.split_config(comp)]
  end, task_defn.components or { "default" })
end
---Check if a component is present on a TaskDefinition
---@param task_defn overseer.TaskDefinition
---@param name string
---@return boolean
function task_util.has_component(task_defn, name)
  for _, comp in ipairs(task_defn.components or { "default" }) do
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

  for _, hook in ipairs(hooks) do
    if hook_matches(hook.opts, opts.search, tmpl.name, tmpl.module) then
      hook.hook(task_defn, task_util)
    end
  end
  if opts.cwd then
    task_defn.cwd = opts.cwd
  end
  if task_defn.env or opts.env then
    task_defn.env = vim.tbl_deep_extend("force", task_defn.env or {}, opts.env or {})
  end
  local task = Task.new(task_defn)
  return task
end

---@class overseer.HookOptions : overseer.SearchCondition
---@field module? string
---@field name? string

---@param opts nil|overseer.HookOptions
---@param hook fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)
M.add_hook_template = function(opts, hook)
  if type(opts) == "string" then
    vim.notify_once(
      "overseer.add_template_hook has changed its call signature. Please update to the new argument format",
      vim.log.levels.WARN
    )
    opts = { name = opts }
  end
  table.insert(hooks, { hook = hook, opts = opts })
end

---@param opts nil|overseer.HookOptions
---@param hook fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)
M.remove_hook_template = function(opts, hook)
  if type(opts) == "string" then
    vim.notify_once(
      "overseer.remove_template_hook has changed its call signature. Please update to the new argument format",
      vim.log.levels.WARN
    )
    opts = { name = opts }
  end
  for i, v in ipairs(hooks) do
    if v.hook == hook and vim.deep_equal(v.opts, opts) then
      table.remove(hooks, i)
      return
    end
  end
end

---@param defn overseer.TemplateDefinition|overseer.TemplateProvider
M.register = function(defn)
  if defn.generator then
    validate_template_provider(defn)
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
---@field search overseer.SearchParams

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
M.clear_cache = function(opts)
  opts = opts or opts
  for _, provider in ipairs(providers) do
    local cache_key = provider.cache_key(opts)
    if cache_key then
      cached_provider_results[cache_key] = nil
    end
  end
end

---@param opts? overseer.SearchParams
---@param cb fun(templates: overseer.TemplateDefinition[])
M.list = function(opts, cb)
  initialize()
  opts = opts or {}
  vim.validate({
    tags = { opts.tags, "t", true },
    dir = { opts.dir, "s" },
    filetype = { opts.filetype, "s", true },
  })

  if not clear_cache_autocmd then
    clear_cache_autocmd = vim.api.nvim_create_autocmd("BufWritePost", {
      desc = "Clear overseer template provider cache when file changed",
      callback = function(params)
        local filename = vim.api.nvim_buf_get_name(params.buf)
        cached_provider_results[filename] = nil
      end,
    })
  end

  local ret = {}
  -- First add all of the simple templates that match the condition
  for _, tmpl in pairs(registry) do
    if condition_matches(tmpl.condition, tmpl.tags, opts, true) then
      table.insert(ret, tmpl)
    end
  end

  local finished_iterating = false
  local pending = {}
  local function final_callback()
    -- Don't finish until we've finished iterating and the last pending async generator is completed
    if not finished_iterating or not vim.tbl_isempty(pending) then
      return
    end
    -- Make sure results are sorted by priority, and then name
    table.sort(ret, function(a, b)
      if a.priority == b.priority then
        return a.name < b.name
      else
        return a.priority < b.priority
      end
    end)

    cb(ret)
  end

  local start_times = {}
  local timed_out = false
  ---This is the async callback that is passed to generators
  ---@param tmpls overseer.TemplateDefinition[]
  ---@param provider_name string
  ---@param module nil|string
  ---@param cache_key nil|string
  local function handle_tmpls(tmpls, provider_name, module, cache_key)
    local elapsed_ms = (vim.loop.hrtime() - start_times[provider_name]) / 1e6
    if
      cache_key
      and config.template_cache_threshold > 0
      and elapsed_ms >= config.template_cache_threshold
    then
      log:debug("Caching %s: [%s] = %d", provider_name, cache_key, #tmpls)
      cached_provider_results[cache_key] = tmpls
    end
    if not pending[provider_name] then
      if not timed_out then
        log:warn("Template %s double-called callback", provider_name)
      end
      return
    end
    pending[provider_name] = nil
    for _, tmpl in ipairs(tmpls) do
      -- Set the module on the template so it can be used to match hooks
      tmpl.module = module
      local ok, err = pcall(validate_template_definition, tmpl)
      if ok then
        if condition_matches(tmpl.condition, tmpl.tags, opts, true) then
          table.insert(ret, tmpl)
        end
      else
        log:error("Template %s from %s: %s", tmpl.name, provider_name, err)
      end
    end

    final_callback()
  end

  -- Timeout
  if config.template_timeout > 0 then
    vim.defer_fn(function()
      if not vim.tbl_isempty(pending) then
        timed_out = true
        log:error("Listing templates timed out. Pending providers: %s", vim.tbl_keys(pending))
        pending = {}
        final_callback()
        -- Make sure that the callback doesn't get called again
        cb = function() end
      end
    end, config.template_timeout)
  end

  for _, provider in ipairs(providers) do
    local provider_name = provider.name
    if condition_matches(provider.condition, nil, opts, false) then
      local cache_key = provider.cache_key(opts)
      local cb = function(tmpls)
        handle_tmpls(tmpls, provider_name, provider.module, cache_key)
      end
      start_times[provider.name] = vim.loop.hrtime()
      pending[provider.name] = true
      if cache_key and cached_provider_results[cache_key] then
        cb(cached_provider_results[cache_key])
      else
        local ok, tmpls = pcall(provider.generator, opts, cb)
        if ok then
          if tmpls then
            -- if there was a return value, the generator completed synchronously
            -- TODO deprecate this flow
            cb(tmpls)
          end
        else
          log:error("Template provider %s: %s", provider.name, tmpls)
        end
      end
    end
  end
  finished_iterating = true
  final_callback()
end

---@param name string
---@param opts? overseer.SearchParams
---@param cb fun(template: overseer.TemplateDefinition)
M.get_by_name = function(name, opts, cb)
  initialize()
  local ret = registry[name]
  if ret then
    cb(ret)
    return
  end
  M.list(opts, function(templates)
    for _, tmpl in ipairs(templates) do
      if tmpl.name == name then
        cb(tmpl)
        return
      end
      if tmpl.aliases then
        for _, alias in ipairs(tmpl.aliases) do
          if alias == name then
            cb(tmpl)
            return
          end
        end
      end
    end
    cb(nil)
  end)
end

return M
