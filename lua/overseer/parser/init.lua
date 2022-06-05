-- Utilities for parsing lines of output
local Enum = require("overseer.enum")
local util = require("overseer.util")
local M = {}

local debug = false
local next_id = 1
local trace = {}

local function add_trace(id, action)
  if not trace[id] then
    trace[id] = { action }
  else
    table.insert(trace[id], action)
  end
end

setmetatable(M, {
  __index = function(_, key)
    local constructor = require(string.format("overseer.parser.%s", key))
    if debug and key ~= "util" and key ~= "debug" then
      return function(...)
        local node = constructor(...)
        local ingest = node.ingest
        local reset = node.reset
        node.reset = function(self)
          add_trace(self.id, "RESET")
          reset(self)
        end
        node.ingest = function(self, line, ctx)
          local depth = ctx.debug_depth or 0
          ctx.debug_depth = depth + 1
          local st = ingest(self, line, ctx)
          add_trace(self.id, st)
          ctx.debug_depth = depth
          return st
        end
        node.id = next_id
        node.name = key
        next_id = next_id + 1
        return node
      end
    else
      return constructor
    end
  end,
})

M.STATUS = Enum.new({
  "RUNNING",
  "SUCCESS",
  "FAILURE",
})

local ListParser = {}

function ListParser.new(children)
  return setmetatable({
    tree = M.loop({ ignore_failure = true }, M.sequence(unpack(children))),
    results = {},
    item = {},
    subs = {},
  }, { __index = ListParser })
end

function ListParser:reset()
  self.tree:reset()
  self.results = {}
  self.item = {}
end

function ListParser:ingest(lines)
  local num_results = #self.results
  local ctx = { item = self.item, results = self.results, default_values = {} }
  for _, line in ipairs(lines) do
    ctx.line = line
    if debug then
      trace = {}
    end
    self.tree:ingest(line, ctx)
  end
  for i = num_results + 1, #self.results do
    local result = self.results[i]
    for _, cb in ipairs(self.subs) do
      cb("", result)
    end
  end
end

function ListParser:subscribe(callback)
  table.insert(self.subs, callback)
end

function ListParser:unsubscribe(callback)
  util.tbl_remove(self.subs, callback)
end

function ListParser:get_result()
  return self.results
end

function ListParser:get_remainder()
  if not vim.tbl_isempty(self.item) then
    return self.item
  end
end

local MapParser = {}

function MapParser.new(children)
  local results = {}
  local items = {}
  local wrapped_children = {}
  for k, v in pairs(children) do
    results[k] = {}
    items[k] = {}
    wrapped_children[k] = M.loop({ ignore_failure = true }, M.sequence(unpack(v)))
  end
  return setmetatable({
    children = wrapped_children,
    results = results,
    items = items,
    subs = {},
  }, { __index = MapParser })
end

function MapParser:reset()
  for k, v in pairs(self.children) do
    self.results[k] = {}
    self.items[k] = {}
    v:reset()
  end
end

function MapParser:ingest(lines)
  for _, line in ipairs(lines) do
    if debug then
      trace = {}
    end
    for k, v in pairs(self.children) do
      local ctx = {
        item = self.items[k],
        results = self.results[k],
        default_values = {},
        line = line,
      }
      local num_results = #ctx.results
      v:ingest(line, ctx)
      for i = num_results + 1, #ctx.results do
        local result = ctx.results[i]
        for _, cb in ipairs(self.subs) do
          cb(k, result)
        end
      end
    end
  end
end

function MapParser:subscribe(callback)
  table.insert(self.subs, callback)
end

function MapParser:unsubscribe(callback)
  util.tbl_remove(self.subs, callback)
end

function MapParser:get_result()
  return self.results
end

function MapParser:get_remainder()
  for _, v in pairs(self.items) do
    if not vim.tbl_isempty(v) then
      return self.items
    end
  end
end

local CustomParser = {}

function CustomParser.new(config)
  vim.validate({
    ingest = { config._ingest, "f" },
    reset = { config._reset, "f", true },
    get_remainder = { config._get_remainder, "f", true },
  })
  config.results = {}
  config.subs = {}
  return setmetatable(config, { __index = CustomParser })
end

function CustomParser:reset()
  self.results = {}
  if self._reset then
    self:_reset()
  end
end

function CustomParser:ingest(lines)
  local num_results = #self.results
  local map_count
  if not vim.tbl_islist(self.results) then
    map_count = {}
    for k, v in pairs(self.results) do
      map_count[k] = #v
    end
  end
  self:_ingest(lines)
  if vim.tbl_islist(self.results) then
    for i = num_results + 1, #self.results do
      local result = self.results[i]
      for _, cb in ipairs(self.subs) do
        cb("", result)
      end
    end
  else
    for k, v in pairs(self.results) do
      for i = map_count and map_count[k] or 1, #v do
        for _, cb in ipairs(self.subs) do
          cb(k, v[i])
        end
      end
    end
  end
end

function CustomParser:subscribe(callback)
  table.insert(self.subs, callback)
end

function CustomParser:unsubscribe(callback)
  util.tbl_remove(self.subs, callback)
end

function CustomParser:get_result()
  print("Get result")
  return self.results
end

function CustomParser:get_remainder()
  if self._get_remainder then
    return self:_get_remainder()
  end
end

M.new = function(config)
  vim.validate({
    config = { config, "t" },
  })
  if vim.tbl_islist(config) then
    return ListParser.new(config)
  elseif config.ingest then
    return config
  else
    return MapParser.new(config)
  end
end

M.custom = function(config)
  vim.validate({
    config = { config, "t" },
  })
  return CustomParser.new(config)
end

M.trace = function(enabled)
  debug = enabled
end

M.get_trace = function()
  return trace
end

return M
