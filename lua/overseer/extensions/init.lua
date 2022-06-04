local component = require("overseer.component")
local template = require("overseer.template")
local M = {}

local builtin_modules = { "make", "npm", "tox", "vscode" }

M.register = function(name)
  if name == "builtin" then
    for _, mod in ipairs(builtin_modules) do
      M.register(mod)
    end
  else
    local path = string.format("overseer.extensions.%s", name)
    component.register_module(path)
    template.register_module(path)
  end
end

return M
