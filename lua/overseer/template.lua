local files = require("overseer.files")
local Task = require("overseer.task")
local template_builder = require("overseer.template_builder")
local util = require("overseer.util")
local M = {}

local builtin_modules = { "go", "make" }

M.register_module = function(path)
  local mod = require(path)
  for _, v in pairs(mod) do
    if type(v) == "table" and v._type == "OverseerTemplate" then
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

local TemplateRegistry = {}

function TemplateRegistry.new()
  return setmetatable({
    templates = {},
  }, { __index = TemplateRegistry })
end

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
    if not condition.callback(search) then
      return false
    end
  end
  return true
end

function TemplateRegistry:get_templates(opts)
  opts = opts or {}
  vim.validate({
    tags = { opts.tags, "t", true },
    dir = { opts.dir, "s" },
    filename = { opts.filename, "s", true },
    filetype = { opts.filetype, "s", true },
  })
  local ret = {}

  for _, tmpl in pairs(self.templates) do
    if tmpl_matches(tmpl, opts) then
      table.insert(ret, tmpl)
    end
  end

  return ret
end

function TemplateRegistry:register(tmpl)
  vim.validate({
    tmpl = { tmpl, "t" },
  })
  if vim.tbl_islist(tmpl) then
    for _, t in ipairs(tmpl) do
      self.templates[t.name] = t
    end
  else
    self.templates[tmpl.name] = tmpl
  end
end

local registry = TemplateRegistry.new()

local Template = {}

function Template.new(opts)
  opts = opts or {}
  vim.validate({
    name = { opts.name, "s" },
    description = { opts.description, "s", true },
    tags = { opts.tags, "t", true },
    params = { opts.params, "t" },
    builder = { opts.builder, "f" },
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

-- These params are always passed in, and are not directly user-controlled
local auto_params = {
  dir = true,
  bufname = true,
}

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
    callback(Task.new(self.builder(params)))
  end

  local schema = {}
  for k, v in pairs(self.params) do
    if not auto_params[k] then
      schema[k] = v
    end
  end
  template_builder.open(self.name, schema, params, function(final_params)
    if final_params then
      callback(Task.new(self.builder(final_params)))
    else
      callback()
    end
  end)
  return
end

M.new = Template.new

M.register = function(...)
  registry:register(...)
end

M.list = function(opts)
  return registry:get_templates(opts)
end

M.get_by_name = function(name, opts)
  local templates = registry:get_templates(opts)
  for _, t in ipairs(templates) do
    if t.name == name then
      return t
    end
  end
end

return M
