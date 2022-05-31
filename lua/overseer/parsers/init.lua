local parser = require("overseer.parser")
local M = {}

local registry = {}

local builtin_modules = { "python" }

M.register_builtin = function()
  for _, path in ipairs(builtin_modules) do
    local mod = require(string.format("overseer.parsers.%s", path))
    for k, v in pairs(mod) do
      registry[k] = v
    end
  end
end

M.get_parser = function(name)
  if registry[name] then
    return parser.new(registry[name]())
  end
end

return M
