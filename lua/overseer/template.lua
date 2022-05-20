local Task = require("overseer.task")
local util = require("overseer.util")
local M = {}

local builtin_modules = { "go", "make" }

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
  if not tags then
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
  for k, _ in pairs(self.params) do
    if params[k] == nil then
      missing = k
      break
    end
  end

  if missing then
    local prompt
    local param = self.params[missing]
    if param.description then
      prompt = string.format("%s (%s)", param.name or missing, param.description)
    else
      prompt = param.name or missing
    end
    vim.ui.input({
      prompt = prompt,
    }, function(val)
      if val then
        params[missing] = val
        self:prompt(params, callback)
      elseif self.params[missing].optional then
        params[missing] = false
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
