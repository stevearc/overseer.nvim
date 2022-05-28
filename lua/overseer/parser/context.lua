local Context = {}

function Context.new(opts, child)
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
    ctx = vim.deepcopy(opts.values),
    status = nil,
    child = child,
  }, { __index = Context })
end

function Context:reset()
  self.ctx = vim.deepcopy(self.default_values)
  self.status = nil
  self.child:reset()
end

function Context:ingest(line, ctx)
  if not self.status and self.hoist_item then
    self.ctx = vim.tbl_extend("force", self.ctx, ctx.item)
  end
  ctx.default_values = vim.tbl_deep_extend("keep", ctx.default_values, self.ctx)
  self.status = self.child:ingest(line, ctx)
  return self.status
end

return Context.new
