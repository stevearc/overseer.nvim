local SetDefaults = {}

function SetDefaults.new(opts, child)
  if child == nil then
    child = opts
    opts = {}
  end
  opts = vim.tbl_deep_extend("keep", opts, {
    values = {},
    hoist_item = true,
  })
  vim.validate({
    values = { opts.values, "t" },
    hoist_item = { opts.hoist_item, "b" },
  })
  if opts.ignore_failure == nil then
    opts.ignore_failure = true
  end
  return setmetatable({
    default_values = opts.values,
    hoist_item = opts.hoist_item,
    current_defaults = nil,
    child = child,
  }, { __index = SetDefaults })
end

function SetDefaults:reset()
  self.current_defaults = nil
  self.child:reset()
end

function SetDefaults:ingest(line, ctx)
  if not self.current_defaults then
    self.current_defaults = vim.deepcopy(self.default_values)
    if self.hoist_item then
      self.current_defaults = vim.tbl_extend("force", self.current_defaults, ctx.item)
    end
  end
  local prev_default_values = ctx.default_values
  ctx.default_values = vim.tbl_deep_extend("force", ctx.default_values or {}, self.current_defaults)
  local status = self.child:ingest(line, ctx)
  ctx.default_values = prev_default_values
  return status
end

return SetDefaults.new
