-- Utilities for parsing lines of output
local Enum = require("overseer.enum")
local util = require("overseer.util")
local M = {}

local debug = false
local next_id = 1
local trace = {}

setmetatable(M, {
  __index = function(_, key)
    local constructor = require(string.format("overseer.parser.%s", key))
    if debug and key ~= "util" and key ~= "debug" then
      return function(...)
        local node = constructor(...)
        local ingest = node.ingest
        node.ingest = function(self, line, ctx)
          local depth = ctx.debug_depth or 0
          ctx.debug_depth = depth + 1
          local st = ingest(self, line, ctx)
          if not trace[self.id] then
            trace[self.id] = { st }
          else
            table.insert(trace[self.id], st)
          end
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
      local ctx = { item = self.items[k], results = self.results[k], default_values = {} }
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

M.new = function(config)
  vim.validate({
    config = { config, "t" },
  })
  if vim.tbl_islist(config) then
    return ListParser.new(config)
  else
    return MapParser.new(config)
  end
end

M.trace = function(enabled)
  debug = enabled
end

M.get_trace = function()
  return trace
end

return M
