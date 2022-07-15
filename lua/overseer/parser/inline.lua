local Inline = {}

function Inline.new(callback, reset)
  return setmetatable({
    callback = callback,
    reset_fn = reset,
  }, { __index = Inline })
end

function Inline:reset()
  if self.reset_fn then
    self.reset_fn()
  end
end

function Inline:ingest(...)
  return self.callback(...)
end

return Inline.new
