local Task = require("overseer.task")
local form = require("overseer.form")
local util = require("overseer.util")
local M = {}

local builtin_modules = { "go", "make", "shell" }

M.register_all = function()
  for _, mod in ipairs(builtin_modules) do
    require(string.format("overseer.template.%s", mod)).register_all()
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
    global = {},
    by_dir = {},
  }, { __index = TemplateRegistry })
end

local function tags_match(tags, tmpl)
  if not tags or vim.tbl_isempty(tags) then
    return true
  end
  if not tmpl.tags then
    return false
  end
  local tag_map = util.list_to_map(tmpl.tags)
  for _, v in ipairs(tags) do
    if not tag_map[v] then
      return false
    end
  end
  return true
end

local function append_matching_templates(ret, ft_map, filetype, tags)
  for _, ft in ipairs({ filetype, "_" }) do
    if ft and ft_map[ft] then
      for _, tmpl in ipairs(ft_map[ft]) do
        if tags_match(tags, tmpl) then
          table.insert(ret, tmpl)
        end
      end
    end
  end
end

function TemplateRegistry:get_templates(opts)
  opts = opts or {}
  vim.validate({
    tags = { opts.tags, "t", true },
    dir = { opts.dir, "s", true },
    filetype = { opts.filetype, "s", true },
  })
  local ret = {}
  if opts.dir then
    local dirs = vim.tbl_keys(self.by_dir)
    -- Iterate the directories from longest to shortest. We would like to add the
    -- *most specific* tasks first.
    table.sort(dirs)
    for i = 1, #dirs do
      local tmpl_dir = dirs[#dirs + 1 - i]
      local ft_map = self.by_dir[tmpl_dir]
      if util.is_subpath(tmpl_dir, opts.dir) then
        append_matching_templates(ret, ft_map, opts.filetype, opts.tags)
      end
    end
  end
  append_matching_templates(ret, self.global, opts.filetype, opts.tags)
  return ret
end

function TemplateRegistry:register(tmpl, opts)
  opts = opts or {}
  vim.validate({
    tmpl = { tmpl, "t" },
    opts = { opts, "t", true },
  })
  vim.validate({
    ["opts.dir"] = { opts.dir, "s", true },
    ["opts.filetype"] = { opts.filetype, "s", true },
  })
  if not vim.tbl_islist(tmpl) then
    tmpl = { tmpl }
  end
  local ft = opts.filetype or "_"
  local ft_map
  if opts.dir then
    if not self.by_dir[opts.dir] then
      self.by_dir[opts.dir] = {}
    end
    ft_map = self.by_dir[opts.dir]
  else
    ft_map = self.global
  end

  if not ft_map[ft] then
    ft_map[ft] = tmpl
  else
    for _, t in ipairs(tmpl) do
      table.insert(ft_map[ft], t)
    end
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
  dirname = true,
  bufname = true,
}

function Template:build(prompt, params, callback)
  local any_missing = false
  local required_missing = false
  for k, schema in pairs(self.params) do
    if not auto_params[k] then
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
  form.show(self.name, schema, params, function(final_params)
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
