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
---@field subscribe fun(self: overseer.Parser, event: string, callback: fun(key: string, value: any))
---@field unsubscribe fun(self: overseer.Parser, event: string, callback: fun(key: string, value: any))
---@field get_result fun(self: overseer.Parser): table
---@field get_remainder fun(self: overseer.Parser): table
---@note
--- Built-in events that can be subscribed to:
---   new_item        Dispatched when an item is appended to the result
---   clear_results   Clear results items from the parser
---   set_results     Canonically used to force the on_output_parse component to set task results

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

---@param subs table<string, fun(key: string, value: any)[]>
---@param event string
---@param callback fun()
local function subscribe(subs, event, callback)
  if not subs[event] then
    subs[event] = {}
  end
  table.insert(subs[event], callback)
end

---@param subs table<string, fun(key: string, value: any)[]>
---@param event string
---@param callback fun()
local function unsubscribe(subs, event, callback)
  if subs[event] then
    util.tbl_remove(subs[event], callback)
  end
end

local function dispatch(subs, event, ...)
  if subs[event] then
    for _, cb in ipairs(subs[event]) do
      cb(...)
    end
  end
end

---@class overseer.ListParser : overseer.Parser
---@field tree overseer.ParserNode
---@field subs table<string, fun(key: string, value: any)[]>
local ListParser = {}

function ListParser.new(children)
  local parser = setmetatable({
    tree = M.loop({ ignore_failure = true }, M.sequence(unpack(children))),
    results = {},
    item = {},
    subs = {},
    num_prev_results = 0,
  }, { __index = ListParser })
  parser:subscribe("clear_results", function(all_results)
    parser.results = {}
    if parser.ctx then
      parser.ctx.results = parser.results
    end
  end)
  return parser
end

function ListParser:reset()
  self.tree:reset()
  self.results = {}
  self.item = {}
  self.num_prev_results = 0
end

function ListParser:ingest(lines)
  self.num_prev_results = #self.results
  self.ctx = {
    item = self.item,
    results = self.results,
    default_values = {},
    dispatch = function(...)
      dispatch(self.subs, ...)
    end,
  }
  for _, line in ipairs(lines) do
    self.ctx.line = line
    if debug then
      trace = {}
    end
    self.tree:ingest(line, self.ctx)
  end
  self.ctx = nil
  for i = self.num_prev_results + 1, #self.results do
    local result = self.results[i]
    dispatch(self.subs, "new_item", "", result)
  end
end

function ListParser:subscribe(event, callback)
  subscribe(self.subs, event, callback)
end

function ListParser:unsubscribe(event, callback)
  unsubscribe(self.subs, event, callback)
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
---@field subs table<string, fun(key: string, value: any)[]>
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
  local parser = setmetatable({
    children = wrapped_children,
    results = results,
    items = items,
    subs = {},
    num_prev_results = {},
  }, { __index = MapParser })
  parser:subscribe("clear_results", function(current_key_only)
    if not current_key_only then
      parser.results = {}
      if parser.ctx then
        parser.results[parser.ctx.__key] = {}
        parser.ctx.results = parser.results[parser.ctx.__key]
      end
    elseif parser.ctx then
      -- We want to clear just the items for the current key in results, so we need to modify the
      -- ctx results in-place
      while not vim.tbl_isempty(parser.ctx.results) do
        table.remove(parser.ctx.results)
      end
    end
  end)
  return parser
end

function MapParser:reset()
  for k, v in pairs(self.children) do
    self.results[k] = {}
    self.items[k] = {}
    self.num_prev_results[k] = 0
    v:reset()
  end
end

function MapParser:ingest(lines)
  for _, line in ipairs(lines) do
    if debug then
      trace = {}
    end
    for k, v in pairs(self.children) do
      self.ctx = {
        __key = k,
        item = self.items[k],
        results = self.results[k],
        default_values = {},
        line = line,
        dispatch = function(...)
          dispatch(self.subs, ...)
        end,
      }
      self.num_prev_results[k] = #self.ctx.results
      v:ingest(line, self.ctx)
      for i = self.num_prev_results[k] + 1, #self.ctx.results do
        local result = self.ctx.results[i]
        dispatch(self.subs, "new_item", k, result)
      end
      self.ctx = nil
    end
  end
end

function MapParser:subscribe(event, callback)
  subscribe(self.subs, event, callback)
end

function MapParser:unsubscribe(event, callback)
  unsubscribe(self.subs, event, callback)
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
