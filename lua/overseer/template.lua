local Task = require('overseer.task')
local M = {}

local TemplateRegistry = {}

function TemplateRegistry.new()
  return setmetatable({
    global = {},
    by_dir = {},
  }, {__index = TemplateRegistry})
end

local function append_matching_templates(ret, ft_map, filetype)
  if filetype and ft_map[filetype] then
    for _,tmpl in ipairs(ft_map[filetype]) do
      table.insert(ret, tmpl)
    end
  end
  if ft_map['_'] then
    for _,tmpl in ipairs(ft_map['_']) do
      table.insert(ret, tmpl)
    end
  end
end

function TemplateRegistry:get_templates(dir, filetype)
  local ret = {}
  local dirs = vim.tbl_keys(self.by_dir)
  -- Iterate the directories from longest to shortest. We would like to add the
  -- *most specific* tasks first.
  table.sort(dirs)
  for i=1,#dirs do
    local tmpl_dir = dirs[#dirs + 1 - i]
    local ft_map = self.by_dir[tmpl_dir]
    if string.sub(dir, 0, string.len(tmpl_dir)) == tmpl_dir then
      append_matching_templates(ret, ft_map, filetype)
    end
  end
  append_matching_templates(ret, self.global, filetype)
  return ret
end

function TemplateRegistry:register(tmpl, opts)
  vim.validate({
    tmpl = {tmpl, 't'},
    opts = {opts, 't', true},
  })
  if opts then
    vim.validate({
      ['opts.dir'] = {opts.dir, 's', true},
      ['opts.filetype'] = {opts.filetype, 's', true},
    })
  end
  if not vim.tbl_islist(tmpl) then
    tmpl = {tmpl}
  end
  local ft = opts.filetype or '_'
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
    for _,t in ipairs(tmpl) do
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
    builder = { opts.builder, "f" },
    params = { opts.params, "t" },
  })
  for _, param in pairs(opts.params) do
    vim.validate({
      name = { param.name, "s", true },
      description = { param.description, "s" },
      optional = { param.optional, "b", true },
    })
  end
  return setmetatable(opts, { __index = Template })
end

function Template:build(params)
  for k, config in pairs(self.params) do
    if params[k] == nil and not config.optional then
      error(string.format("Missing param %s", k))
    end
  end
  return Task.new(self.builder(params))
end

function Template:prompt(params, callback)
  vim.validate({
    params = { params, "t" },
    callback = { callback, "f" },
  })

  local missing
  -- FIXME handle optional params
  for k,_ in pairs(self.params) do
    if params[k] == nil then
      missing = k
      break
    end
  end

  if missing then
    vim.ui.input({
      prompt = string.format("%s (%s)", self.params[missing].name or missing, self.params[missing].description),
    }, function(val)
      if val then
        params[missing] = val
        self:prompt(params, callback)
      end
    end)
  else
    callback(Task.new(self.builder(params)))
  end
end

M.new = Template.new

M.register = function(...)
  registry:register(...)
end

M.list = function(dir, filetype)
  return registry:get_templates(dir, filetype)
end

M.get_by_name = function(name, dir, filetype)
  local templates = registry:get_templates(dir, filetype)
  for _,t in ipairs(templates) do
    if t.name == name then
      return t
    end
  end
end

return M
