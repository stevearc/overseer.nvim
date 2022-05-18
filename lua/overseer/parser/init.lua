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

---@class overseer.Parser
---@field reset fun(self: overseer.Parser)
---@field ingest fun(self: overseer.Parser, lines: string[])
---@field subscribe fun(self: overseer.Parser, callback: fun(key: string, value: any))
---@field unsubscribe fun(self: overseer.Parser, callback: fun(key: string, value: any))
---@field get_result fun(self: overseer.Parser): table
---@field get_remainder fun(self: overseer.Parser): table

---@class overseer.ParserNode
---@field ingest fun(self: overseer.ParserNode, line: string, ctx: table): overseer.ParserStatus
---@field reset fun()

setmetatable(M, {
  __index = function(_, key)
    local mod = require(string.format("overseer.parser.%s", key))
    if key == "util" or key == "debug" then
      return mod
    end
    if debug then
      return function(...)
        local node = mod.new(...)
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
      return mod.new
    end
  end,
})

---@alias overseer.ParserStatus "RUNNING"|"SUCCESS"|"FAILURE"

M.STATUS = Enum.new({
  "RUNNING",
  "SUCCESS",
  "FAILURE",
})

---@class overseer.ListParser : overseer.Parser
---@field tree overseer.ParserNode
---@field subs fun(key: string, value: any)[]
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

---@class overseer.MapParser : overseer.Parser
---@field children table<string, overseer.ParserNode>
---@field results table<string, table>
---@field items table<string, table>
---@field subs fun(key: string, value: any)[]
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

---@param config table
---@return overseer.Parser
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

---@param enabled boolean
M.trace = function(enabled)
  debug = enabled
end

---@return boolean
M.get_trace = function()
  return trace
end

---Used for documentation generation
---@private
M.get_parser_docs = function(name)
  local mod = require(string.format("overseer.parser.%s", name))
  if mod.doc_args then
    return {
      name = name,
      desc = mod.desc,
      doc_args = mod.doc_args,
      examples = mod.examples,
    }
  else
    return {}
  end
end

return M
