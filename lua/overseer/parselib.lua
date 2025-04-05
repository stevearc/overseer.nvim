local M = {}

---@class (exact) overseer.OutputParser
---@field parse fun(self: overseer.OutputParser, line: string)
---@field get_result fun(self: overseer.OutputParser): table<string, any>
---@field reset fun(self: overseer.OutputParser)
---@field result_version? number For background parsers only, this number should be bumped to indicate that the task should set the result while the process is still running

---@alias overseer.TestFn fun(line: string): boolean
---@alias overseer.ParseFn fun(line: string): nil|vim.quickfix.entry
---@alias overseer.MatchFn fun(line: string): nil|string[]

---@alias overseer.FieldProcessor fun(match: string, item: vim.quickfix.entry, field: string): any
---@alias overseer.ParseFieldWithConversion {[1]: string, [2]: overseer.FieldProcessor}

---@alias overseer.ParseField string|overseer.ParseFieldWithConversion

---@type overseer.FieldProcessor
local function default_postprocess_field(value, _, field)
  if value:match("^%d+$") then
    return tonumber(value)
  elseif field == "type" then
    return value:upper():match("^%w")
  else
    return value
  end
end

---Create a match function from a lua pattern
---@param pattern string lua pattern
---@return overseer.MatchFn
M.make_lua_match_fn = function(pattern)
  return function(line)
    local ret = { line:match(pattern) }
    if vim.tbl_isempty(ret) then
      return nil
    end
    return ret
  end
end

---Create a match function from a vim regex
---@param pattern string vim regex, passed to vim.fn.matchlist
---@return overseer.MatchFn
M.make_regex_match_fn = function(pattern)
  return function(line)
    local result = vim.fn.matchlist(line, pattern)
    if vim.tbl_isempty(result) then
      return nil
    end
    table.remove(result, 1)
    -- matchlist() will use "" if an optional submatch does not match, and it also throws a
    -- bunch of "" on the end of the list just for funzies.
    for i, v in ipairs(result) do
      if v == "" then
        result[i] = nil
      end
    end
    return result
  end
end

---Create a test function (returns true/false) from a match function
---@param match overseer.MatchFn
---@return overseer.TestFn
M.match_to_test_fn = function(match)
  return function(line)
    local ret = match(line)
    return ret ~= nil
  end
end

---Create a function that parses a line into a quickfix entry
---@param match overseer.MatchFn
---@param fields overseer.ParseField[] list of field names, or {field_name, postprocess_fn} tuples
---@return overseer.ParseFn
M.make_parse_fn = function(match, fields)
  return function(line)
    local result = match(line)
    if not result then
      return nil
    end
    local item
    for i, field in ipairs(fields) do
      if result[i] then
        if not item then
          item = {}
        end
        local key, postprocess
        if type(field) == "table" then
          key, postprocess = field[1], field[2]
        else
          key = field
        end
        if not postprocess then
          postprocess = default_postprocess_field
        end
        if key ~= "_" then
          item[key] = postprocess(result[i], item, key)
        end
      end
    end
    return item
  end
end

---Create a parser from a vim errorformat
---@param errorformat string
---@return overseer.OutputParser
M.parser_from_errorformat = function(errorformat)
  local result = {}
  local pending_lines = {}
  local last_item_pending = false
  ---@type overseer.OutputParser
  return {
    parse = function(_, line)
      table.insert(pending_lines, line)
      local items = vim.fn.getqflist({
        lines = pending_lines,
        efm = errorformat,
      }).items
      local valid_items = vim.tbl_filter(function(item)
        return item.valid == 1
      end, items)

      if #valid_items > 1 then
        table.insert(result, valid_items[2])
        last_item_pending = true
        pending_lines = { line }
      elseif #valid_items == 1 then
        if last_item_pending then
          result[#result] = valid_items[1]
        else
          table.insert(result, valid_items[1])
        end
        last_item_pending = true
      else
        last_item_pending = false
        pending_lines = {}
      end
    end,
    get_result = function()
      return { diagnostics = result }
    end,
    reset = function()
      result = {}
    end,
  }
end

---Create a parser from a parse function
---@param parse_fn overseer.ParseFn
---@param results_key? string The key to put matches in the results table. defaults to "diagnostics"
---@return overseer.OutputParser
M.make_parser = function(parse_fn, results_key)
  if not results_key then
    results_key = "diagnostics"
  end
  local result = {}
  ---@type overseer.OutputParser
  return {
    parse = function(_, line)
      local item = parse_fn(line)
      if item then
        table.insert(result, item)
      end
    end,
    get_result = function()
      return { [results_key] = result }
    end,
    reset = function()
      result = {}
    end,
  }
end

---Combine multiple parsers into a single one (will merge the results)
---@param parsers overseer.OutputParser[]
---@return overseer.OutputParser
M.combine_parsers = function(parsers)
  ---@type overseer.OutputParser
  return {
    result_version = 0,
    parse = function(self, line)
      local version = 0
      for _, parser in ipairs(parsers) do
        parser:parse(line)
        if parser.result_version then
          version = version + parser.result_version
        end
      end
      self.result_version = version
    end,
    get_result = function()
      local ret = {}
      for _, parser in ipairs(parsers) do
        local res = parser:get_result()
        for k, v in pairs(res) do
          if not ret[k] then
            ret[k] = v
          elseif vim.islist(v) and vim.islist(ret[k]) then
            local new_list = vim.list_extend({}, ret[k])
            vim.list_extend(new_list, v)
            ret[k] = new_list
          elseif type(v) == "table" and type(ret[k]) == "table" then
            ret[k] = vim.tbl_deep_extend("force", ret[k], v)
          else
            ret[k] = v
          end
        end
      end
      return ret
    end,
    reset = function()
      for _, parser in ipairs(parsers) do
        parser:reset()
      end
    end,
  }
end

---Wrap a parser and only activate it in between a matching start and end lines
---@param parser overseer.OutputParser
---@param opts {active_on_start?: boolean, start_fn?: overseer.TestFn, end_fn?: overseer.TestFn}
---@return overseer.OutputParser
M.wrap_background_parser = function(parser, opts)
  local is_active = opts.active_on_start
  ---@type overseer.OutputParser
  return {
    result_version = 0,
    parse = function(self, line)
      if is_active then
        if opts.end_fn and opts.end_fn(line) then
          self.result_version = self.result_version + 1
          is_active = false
        else
          parser:parse(line)
        end
      elseif opts.start_fn and opts.start_fn(line) then
        is_active = true
        parser:reset()
        -- Only bump the version if we have ever had results.
        -- If we have previously set results on the task, hitting the start pattern again should
        -- clear them immediately.
        if self.result_version ~= 0 then
          self.result_version = self.result_version + 1
        end
      end
    end,
    get_result = function()
      return parser:get_result()
    end,
    reset = function(self)
      self.result_version = 0
      is_active = opts.active_on_start
      parser:reset()
    end,
  }
end

return M
