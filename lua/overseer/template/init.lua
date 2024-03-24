local component = require("overseer.component")
local config = require("overseer.config")
local files = require("overseer.files")
local form = require("overseer.form")
local form_utils = require("overseer.form.utils")
local log = require("overseer.log")
local util = require("overseer.util")
local M = {}

---@class overseer.TemplateFileProvider
---@field module? string The name of the module this was loaded from
---@field condition? overseer.SearchCondition
---@field cache_key? fun(opts: overseer.SearchParams): nil|string
---@field generator fun(opts: overseer.SearchParams, cb: fun(tmpls: overseer.TemplateDefinition[]))

---@class overseer.TemplateProvider : overseer.TemplateFileProvider
---@field name string

---@class overseer.TemplateFileDefinition
---@field module? string The name of the module this was loaded from
---@field aliases? string[]
---@field desc? string
---@field tags? string[]
---@field params? overseer.Params
---@field priority? number
---@field condition? overseer.SearchCondition
---@field builder fun(params: table): overseer.TaskDefinition
---@field hide? boolean Hide from the template list

---@class overseer.TemplateDefinition : overseer.TemplateFileDefinition
---@field name string

---@class overseer.SearchCondition
---@field filetype? string|string[]
---@field dir? string|string[]
---@field callback? fun(search: overseer.SearchParams): boolean, nil|string

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

---@param condition? overseer.SearchCondition Template conditions
---@param tags? string[] Template tags
---@param search overseer.SearchParams Search parameters
---@param match_tags boolean Require that tags match
---@return boolean match
---@return nil|string reason
local function condition_matches(condition, tags, search, match_tags)
  condition = condition or {}
  if condition.filetype then
    local search_fts = vim.split(search.filetype, ".", { plain = true })
    local any_ft_match = false
    for _, ft in util.iter_as_list(condition.filetype) do
      if vim.tbl_contains(search_fts, ft) then
        any_ft_match = true
        break
      end
    end
    if not any_ft_match then
      return false, string.format("Does not match filetype %s", vim.inspect(condition.filetype))
    end
  end

  local dir = condition.dir
  if dir then
    if type(dir) == "string" then
      if not files.is_subpath(dir, search.dir) then
        return false, string.format("Not in dir %s", condition.dir)
      end
    elseif
      not util.list_any(dir, function(d)
        return files.is_subpath(d, search.dir)
      end)
    then
      return false, string.format("Not in dirs %s", table.concat(dir, ", "))
    end
  end

  if match_tags and search.tags and not vim.tbl_isempty(search.tags) then
    if not tags then
      return false, string.format("Doesn't have tags %s", vim.inspect(search.tags))
    end
    local tag_map = util.list_to_map(tags)
    for _, v in ipairs(search.tags) do
      if not tag_map[v] then
        return false, string.format("Doesn't have tags %s", vim.inspect(search.tags))
      end
    end
  end

  if condition.callback then
    local passed, message = condition.callback(search)
    if not passed then
      return false, message
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
    local register_ok, err = pcall(M.register, defn)
    if not register_ok then
      log:error("Error loading template '%s': %s", name, err)
    end
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
  form_utils.validate_params(defn.params)
end

---@class overseer.TaskUtil
local task_util = {}
---Add one or more components to a TaskDefinition
---@param task_defn overseer.TaskDefinition
---@param ... overseer.Serialized[]
function task_util.add_component(task_defn, ...)
  local names = vim.tbl_map(util.split_config, { ... })
  task_util.remove_component(task_defn, unpack(names))
  task_defn.components = vim.list_extend({ ... }, task_defn.components)
end
---Remove one or more components from a TaskDefinition
---@param task_defn overseer.TaskDefinition
---@param ... string[]
function task_util.remove_component(task_defn, ...)
  local to_remove = util.list_to_map({ ... })
  task_defn.components = vim.tbl_filter(function(comp)
    return not to_remove[util.split_config(comp)]
  end, task_defn.components)
end
---Check if a component is present on a TaskDefinition
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
---@param search overseer.SearchParams
---@param params table
---@return overseer.TaskDefinition
local function build_task_args(tmpl, search, params)
  local task_defn = tmpl.builder(params)
  task_defn.components = component.resolve(task_defn.components or { "default" })

  for _, hook in ipairs(hooks) do
    if hook_matches(hook.opts, search, tmpl.name, tmpl.module) then
      hook.hook(task_defn, task_util)
    end
  end

  return task_defn
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
    ---@cast defn overseer.TemplateProvider
    validate_template_provider(defn)
    table.insert(providers, defn)
  else
    ---@cast defn overseer.TemplateDefinition
    validate_template_definition(defn)
    registry[defn.name] = defn
  end
end

---Check if template should prompt user for input. Exposed for testing
---@private
---@param prompt "always"|"never"|"allow"|"missing"|"avoid"
---@param param_schema table
---@param params table
---@return nil|boolean
---@return nil|string Error message if error is present
M._should_prompt = function(prompt, param_schema, params)
  if vim.tbl_isempty(param_schema) then
    return false
  end
  local show_prompt = prompt == "always"
  for k, schema in pairs(param_schema) do
    -- This parameter has no value passed in via the API
    if params[k] == nil then
      if prompt == "missing" then
        show_prompt = true
      end
      local has_default = schema.default ~= nil
      if has_default then
        -- Set the default value into the params, if any
        params[k] = vim.deepcopy(schema.default)
      end

      -- If the param is not optional, process possible prompt values to show the prompt or error
      if not schema.optional then
        if prompt == "allow" then
          show_prompt = true
        end
        if not has_default then
          if prompt == "avoid" then
            show_prompt = true
          elseif prompt == "never" then
            return nil, string.format("Missing param %s", k)
          end
        end
      end
    end
  end
  return show_prompt
end

---@class overseer.TemplateBuildOpts
---@field prompt? "always"|"never"|"allow"|"missing"|"avoid"
---@field params table
---@field search overseer.SearchParams

---@param tmpl overseer.TemplateDefinition
---@param opts overseer.TemplateBuildOpts
---@param callback fun(task: overseer.TaskDefinition|nil, err: string|nil)
M.build_task_args = function(tmpl, opts, callback)
  vim.validate({
    prompt = { opts.prompt, "s", true },
    params = { opts.params, "t" },
  })
  opts.prompt = opts.prompt or config.default_template_prompt
  local show_prompt, err = M._should_prompt(opts.prompt, tmpl.params, opts.params)
  if err then
    return callback(nil, err)
  end
  if not show_prompt then
    callback(build_task_args(tmpl, opts.search, opts.params))
    return
  end

  local schema = {}
  for k, v in pairs(tmpl.params) do
    schema[k] = v
  end
  form.open(tmpl.name, schema, opts.params, function(final_params)
    if final_params then
      callback(build_task_args(tmpl, opts.search, final_params))
    else
      callback()
    end
  end)
end

---@class overseer.SearchParams
---@field filetype? string
---@field tags? string[]
---@field dir string

---@param opts overseer.SearchParams
M.clear_cache = function(opts)
  for _, provider in ipairs(providers) do
    local cache_key = provider.cache_key(opts)
    if cache_key then
      cached_provider_results[cache_key] = nil
    end
  end
end

---@param opts overseer.SearchParams
---@param cb fun(templates: overseer.TemplateDefinition[], report: table)
M.list = function(opts, cb)
  initialize()
  vim.validate({
    tags = { opts.tags, "t", true },
    dir = { opts.dir, "s" },
    filetype = { opts.filetype, "s", true },
  })
  -- Make sure the search dir is an absolute path
  opts.dir = vim.fn.fnamemodify(opts.dir, ":p")

  if not clear_cache_autocmd then
    clear_cache_autocmd = vim.api.nvim_create_autocmd("BufWritePost", {
      desc = "Clear overseer template provider cache when file changed",
      callback = function(params)
        local filename = vim.api.nvim_buf_get_name(params.buf)
        cached_provider_results[filename] = nil

        -- Also clear the cache of the parent directory
        local dirname = vim.fs.dirname(filename)
        cached_provider_results[dirname] = nil
      end,
    })
  end

  local ret = {}
  local report = {
    templates = {},
    providers = {},
  }
  -- First add all of the simple templates that match the condition
  for _, tmpl in pairs(registry) do
    local is_match, message = condition_matches(tmpl.condition, tmpl.tags, opts, true)
    if is_match then
      table.insert(ret, tmpl)
    end
    report.templates[tmpl.name] = {
      is_present = is_match,
      message = message,
    }
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

    cb(ret, report)
  end

  local start_times = {}
  local timed_out = false
  ---This is the async callback that is passed to generators
  ---@param tmpls overseer.TemplateDefinition[]
  ---@param provider_name string
  ---@param module nil|string
  ---@param cache_key nil|string
  ---@param from_cache nil|boolean
  local function handle_tmpls(tmpls, provider_name, module, cache_key, from_cache)
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
    local num_available = 0
    for _, tmpl in ipairs(tmpls) do
      -- Set the module on the template so it can be used to match hooks
      tmpl.module = module
      local ok, err = pcall(validate_template_definition, tmpl)
      if ok then
        if condition_matches(tmpl.condition, tmpl.tags, opts, true) then
          num_available = num_available + 1
          table.insert(ret, tmpl)
        end
      else
        log:error("Template %s from %s: %s", tmpl.name, provider_name, err)
      end
    end
    report.providers[provider_name] = {
      is_present = true,
      message = nil,
      from_cache = from_cache,
      total_tasks = #tmpls,
      available_tasks = num_available,
    }

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
    local is_match, message = condition_matches(provider.condition, nil, opts, false)
    if is_match then
      local cache_key = provider.cache_key(opts)
      local provider_cb = function(tmpls)
        handle_tmpls(tmpls, provider_name, provider.module, cache_key)
      end
      start_times[provider.name] = vim.loop.hrtime()
      pending[provider.name] = true
      if cache_key and cached_provider_results[cache_key] then
        handle_tmpls(
          cached_provider_results[cache_key],
          provider_name,
          provider.module,
          cache_key,
          true
        )
      else
        local ok, tmpls = pcall(provider.generator, opts, provider_cb)
        if ok then
          if tmpls then
            -- if there was a return value, the generator completed synchronously
            -- TODO deprecate this flow
            provider_cb(tmpls)
          end
        else
          log:error("Template provider %s: %s", provider.name, tmpls)
        end
      end
    else
      report.providers[provider_name] = {
        is_present = is_match,
        message = message,
        total_tasks = 0,
        available_tasks = 0,
      }
    end
  end
  finished_iterating = true
  final_callback()
end

---@param name string
---@param opts overseer.SearchParams
---@param cb fun(template: nil|overseer.TemplateDefinition)
M.get_by_name = function(name, opts, cb)
  initialize()
  local ret = registry[name]
  if ret and condition_matches(ret.condition, ret.tags, opts, false) then
    cb(ret)
    return
  end
  M.list(opts, function(templates)
    for _, tmpl in ipairs(templates) do
      if tmpl.name == name or (tmpl.aliases and vim.tbl_contains(tmpl.aliases, name)) then
        cb(tmpl)
        return
      end
    end
    cb(nil)
  end)
end

return M
