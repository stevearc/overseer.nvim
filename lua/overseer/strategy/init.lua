local util = require("overseer.util")
local M = {}

---@class overseer.Strategy
---@field name string
---@field reset fun(self: overseer.Strategy)
---@field get_bufnr fun(): number|nil
---@field start fun(self: overseer.Strategy, task: overseer.Task)
---@field stop fun(self: overseer.Strategy)
---@field dispose fun(self: overseer.Strategy)

---@param name_or_config overseer.Serialized
---@return overseer.Strategy
M.load = function(name_or_config)
  local conf
  local name
  name, conf = util.split_config(name_or_config)
  local strategy = require(string.format("overseer.strategy.%s", name))
  local instance = strategy.new(conf)
  instance.name = name
  return instance
end

return M
