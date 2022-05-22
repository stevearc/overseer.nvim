local files = require("overseer.files")
local Task = require("overseer.task")
local template_builder = require("overseer.template_builder")
local util = require("overseer.util")
local M = {}

local builtin_modules = { "go", "make", "npm" }

local Template = {}

M.is_template = function(obj)
  if type(obj) ~= "table" then
    return false
  end
  if obj._type == "OverseerTemplate" then
    return true
  end
  if obj.name and obj.params and obj.builder then
    return true
  end
  return false
end

M.register_module = function(path)
  local mod = require(path)
  for _, v in pairs(mod) do
    if M.is_template(v) then
      M.register(v)
    end
  end
end

M.register_builtin = function()
  for _, mod in ipairs(builtin_modules) do
    M.register_module(string.format("overseer.template.%s", mod))
  end
  -- For testing and debugging
  M.register(M.new({
    name = "sleep",
    builder = function(params)
      return {
        cmd = { "sleep", params.duration },
      }
    end,
    params = {
      duration = {},
    },
  }))
end

local registry = {}

local function tmpl_matches(tmpl, search)
  local condition = tmpl.condition
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
    if not tmpl.tags then
      return false
    end
    local tag_map = util.list_to_map(tmpl.tags)
    for _, v in ipairs(search.tags) do
      if not tag_map[v] then
        return false
      end
    end
  end

  if condition.callback then
    if not condition.callback(tmpl, search) then
      return false
    end
  end
  return true
end

M.list = function(opts)
  opts = opts or {}
  vim.validate({
    tags = { opts.tags, "t", true },
    dir = { opts.dir, "s" },
    filetype = { opts.filetype, "s", true },
  })
  local ret = {}

  for _, tmpl in pairs(registry) do
    if tmpl_matches(tmpl, opts) then
      table.insert(ret, tmpl)
      if tmpl.metagen then
        for _, meta in ipairs(tmpl:metagen(opts)) do
          table.insert(ret, meta)
        end
      end
    end
  end

  return ret
end

M.register = function(tmpl)
  vim.validate({
    tmpl = { tmpl, "t" },
  })
  if not vim.tbl_islist(tmpl) then
    tmpl = { tmpl }
  end
  for _, t in ipairs(tmpl) do
    if t._type ~= "OverseerTemplate" then
      t = Template.new(t)
    end
    registry[t.name] = t
  end
end

function Template.new(opts)
  opts = opts or {}
  vim.validate({
    name = { opts.name, "s" },
    description = { opts.description, "s", true },
    tags = { opts.tags, "t", true },
    params = { opts.params, "t" },
    builder = { opts.builder, "f" },
    metagen = { opts.metagen, "f", true },
  })
  opts._type = "OverseerTemplate"
  if opts.condition then
    vim.validate({
      -- filetype can be string or list of strings
      -- dir can be string or list of strings
      ["condition.callback"] = { opts.condition.callback, "f", true },
    })
  else
    opts.condition = {}
  end
  for _, param in pairs(opts.params) do
    vim.validate({
      name = { param.name, "s", true },
      description = { param.description, "s", true },
      optional = { param.optional, "b", true },
      -- default = any type
    })
  end
  return setmetatable(opts, { __index = Template })
end

function Template:build(prompt, params, callback)
  local any_missing = false
  local required_missing = false
  for k, schema in pairs(self.params) do
    if params[k] == nil then
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

  if
    prompt == "never"
    or (prompt == "allow" and not required_missing)
    or (prompt == "missing" and not any_missing)
    or vim.tbl_isempty(self.params)
  then
    callback(Task.new(self:builder(params)))
    return
  end

  local schema = {}
  for k, v in pairs(self.params) do
    schema[k] = v
  end
  template_builder.open(self.name, schema, params, function(final_params)
    if final_params then
      callback(Task.new(self:builder(final_params)))
    else
      callback()
    end
  end)
  return
end

function Template:wrap(name, default_params)
  return setmetatable({
    name = name,
    build = function(newself, prompt, params, callback)
      for k, v in pairs(default_params) do
        params[k] = v
      end
      return self:build(prompt, params, callback)
    end,
  }, { __index = self })
end

M.new = Template.new

M.get_by_name = function(name)
  return registry[name]
end

return M
