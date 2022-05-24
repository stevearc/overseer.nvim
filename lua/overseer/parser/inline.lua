local Inline = {}

function Inline.new(callback, reset)
  return setmetatable({
    callback = callback,
    reset = reset,
  }, { __index = Inline })
end

function Inline:reset()
  if self.reset then
    self.reset()
  end
end

function Inline:ingest(...)
  return self.callback(...)
end

return Inline.new
