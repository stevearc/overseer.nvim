local config = require("overseer.config")
local log = require("overseer.log")
local util = require("overseer.util")
local M = {}

---@class overseer.Strategy
---@field name string
---@field new function
---@field reset fun(self: overseer.Strategy)
---@field get_bufnr fun(): number|nil
---@field start fun(self: overseer.Strategy, task: overseer.Task)
---@field stop fun(self: overseer.Strategy)
---@field dispose fun(self: overseer.Strategy)
---@field render nil|fun(self: overseer.Strategy, lines: string[], highlights: table, detail: number)

local NilStrategy = {}

---@return overseer.Strategy
function NilStrategy.new()
  return setmetatable({}, { __index = NilStrategy })
end

function NilStrategy:reset() end

function NilStrategy:get_bufnr() end

function NilStrategy:start()
  error(string.format("Strategy '%s' not found", self.name))
end

function NilStrategy:stop() end

function NilStrategy:dispose() end

---@param name_or_config string|table
---@return overseer.Strategy
M.load = function(name_or_config)
  if not name_or_config then
    name_or_config = config.strategy
  end
  local conf
  local name
  name, conf = util.split_config(name_or_config)
  local ok, strategy = pcall(require, string.format("overseer.strategy.%s", name))
  if ok then
    local instance = strategy.new(conf)
    instance.name = name
    return instance
  else
    log:error("No task strategy '%s'", name)
    return NilStrategy
  end
end

return M
