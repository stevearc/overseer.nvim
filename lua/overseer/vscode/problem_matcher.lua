local log = require("overseer.log")
local parselib = require("overseer.parselib")
local variables = require("overseer.vscode.variables")
local M = {}

-- Taken from https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/tasks/common/problemMatcher.ts#L1207
local default_patterns = {
  ["$msCompile"] = {
    regexp = "^(?:\\s(\\d+>)?(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\)\\s*:\\s+((?:fatal +)?error|warning|info)\\s+(\\w+\\d+)\\s*:\\s*(.*)$",
    vim_regexp = "\\v^%(\\s*\\d+>)?(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\)\\s*:\\s+(%(fatal +)?error|warning|info)\\s+(\\w+\\d+)\\s*:\\s*(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    code = 4,
    message = 5,
  },
  ["$gulp-tsc"] = {
    regexp = "^([^\\s].*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(\\d+)\\s+(.*)$",
    vim_regexp = "\\v^([^[:space:]].*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(\\d+)\\s+(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    code = 3,
    message = 4,
  },
  ["$cpp"] = {
    regexp = "^(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(error|warning|info)\\s+(C\\d+)\\s*:\\s*(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    code = 4,
    message = 5,
  },
  ["$csc"] = {
    regexp = "^(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(error|warning|info)\\s+(CS\\d+)\\s*:\\s*(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    code = 4,
    message = 5,
  },
  ["$vb"] = {
    regexp = "^(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(error|warning|info)\\s+(BC\\d+)\\s*:\\s*(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    code = 4,
    message = 5,
  },
  ["$lessCompile"] = {
    regexp = "^\\s*(.*) in file (.*) line no. (\\d+)$",
    kind = "location",
    message = 1,
    file = 2,
    line = 3,
  },
  ["$jshint"] = {
    regexp = "^(.*):\\s+line\\s+(\\d+),\\s+col\\s+(\\d+),\\s(.+?)(?:\\s+\\((\\w)(\\d+)\\))?$",
    vim_regexp = "\\v^(.*):\\s+line\\s+(\\d+),\\s+col\\s+(\\d+),\\s(.{-1,})%(\\s+\\((\\w)(\\d+)\\))?$",
    kind = "location",
    file = 1,
    line = 2,
    character = 3,
    message = 4,
    severity = 5,
    code = 6,
  },
  ["$jshint-stylish"] = {
    {
      regexp = "^(.+)$",
      kind = "location",
      file = 1,
    },
    {
      regexp = "^\\s+line\\s+(\\d+)\\s+col\\s+(\\d+)\\s+(.+?)(?:\\s+\\((\\w)(\\d+)\\))?$",
      vim_regexp = "\\v^\\s+line\\s+(\\d+)\\s+col\\s+(\\d+)\\s+(.{-1,})%(\\s+\\((\\w)(\\d+)\\))?$",
      line = 1,
      character = 2,
      message = 3,
      severity = 4,
      code = 5,
      loop = true,
    },
  },
  ["$eslint-compact"] = {
    regexp = "^(.+):\\sline\\s(\\d+),\\scol\\s(\\d+),\\s(Error|Warning|Info)\\s-\\s(.+)\\s\\((.+)\\)$",
    file = 1,
    kind = "location",
    line = 2,
    character = 3,
    severity = 4,
    message = 5,
    code = 6,
  },
  ["$eslint-stylish"] = {
    {
      regexp = "^((?:[a-zA-Z]:)*[./\\\\]+.*?)$",
      vim_regexp = "\\v^(%([a-zA-Z]:)*[./\\\\]+.{-})$",
      kind = "location",
      file = 1,
    },
    {
      regexp = "^\\s+(\\d+):(\\d+)\\s+(error|warning|info)\\s+(.+?)(?:\\s\\s+(.*))?$",
      vim_regexp = "\\v^\\s+(\\d+):(\\d+)\\s+(error|warning|info)\\s+(.{-1,})%(\\s\\s+(.*))?$",
      line = 1,
      character = 2,
      severity = 3,
      message = 4,
      code = 5,
      loop = true,
    },
  },
  ["$go"] = {
    regexp = "^([^:]*: )?((.:)?[^:]*):(\\d+)(:(\\d+))?: (.*)$",
    kind = "location",
    file = 2,
    line = 4,
    character = 6,
    message = 7,
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/typescript-language-features/package.json#L1396
  ["$tsc"] = {
    regexp = "^([^\\s].*)[\\(:](\\d+)[,:](\\d+)(?:\\):\\s+|\\s+-\\s+)(error|warning|info)\\s+TS(\\d+)\\s*:\\s*(.*)$",
    vim_regexp = "\\v^([^[:space:]].*)[\\(:](\\d+)[,:](\\d+)%(\\):\\s+|\\s+-\\s+)(error|warning|info)\\s+TS(\\d+)\\s*:\\s*(.*)$",
    file = 1,
    line = 2,
    column = 3,
    severity = 4,
    code = 5,
    message = 6,
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/cpp/package.json#L95
  ["$nvcc-location"] = {
    regexp = "^(.*)\\((\\d+)\\):\\s+(warning|error):\\s+(.*)",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    message = 4,
  },
}

local default_matchers = {
  -- from https://github.com/microsoft/vscode/blob/448ec31cb2d4c65a1ca7845b322d61d5d542d8b1/src/vs/workbench/contrib/tasks/common/problemMatcher.ts#L1924-L2007
  ["$msCompile"] = {
    owner = "msCompile",
    source = "cpp",
    pattern = "$msCompile",
  },
  ["$lessCompile"] = {
    owner = "lessCompile",
    deprecated = true,
    source = "less",
    pattern = "$lessCompile",
  },
  ["$gulp-tsc"] = {
    owner = "typescript",
    source = "ts",
    pattern = "$gulp-tsc",
  },
  ["$jshint"] = {
    owner = "jshint",
    source = "jshint",
    pattern = "$jshint",
  },
  ["$jshint-stylish"] = {
    owner = "jshint",
    source = "jshint",
    pattern = "$jshint-stylish",
  },
  ["$eslint-compact"] = {
    owner = "eslint",
    source = "eslint",
    pattern = "$eslint-compact",
  },
  ["$eslint-stylish"] = {
    owner = "eslint",
    source = "eslint",
    pattern = "$eslint-stylish",
  },
  ["$go"] = {
    owner = "go",
    source = "go",
    pattern = "$go",
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/typescript-language-features/package.json#L1396
  ["$tsc"] = {
    owner = "typescript",
    source = "ts",
    applyTo = "closedDocuments",
    fileLocation = { "relative", "${cwd}" },
    pattern = "$tsc",
  },
  ["$tsc-watch"] = {
    fileLocation = { "relative", "${cwd}" },
    pattern = "$tsc",
    background = {
      activeOnStart = true,
      beginsPattern = {
        regexp = "^\\s*(?:message TS6032:|\\[?\\D*.{1,2}[:.].{1,2}[:.].{1,2}\\D*(├\\D*\\d{1,2}\\D+┤)?(?:\\]| -)) File change detected\\. Starting incremental compilation\\.\\.\\.",
        lua_pat = "File change detected%. Starting incremental compilation%.%.%.$",
      },
      endsPattern = {
        regexp = "^\\s*(?:message TS6042:|\\[?\\D*.{1,2}[:.].{1,2}[:.].{1,2}\\D*(├\\D*\\d{1,2}\\D+┤)?(?:\\]| -)) (?:Compilation complete\\.|Found \\d+ errors?\\.) Watching for file changes\\.",
        lua_pat = "Watching for file changes%.$",
      },
    },
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/cpp/package.json#L95
  ["$nvcc"] = {
    fileLocation = { "relative", "${workspaceFolder}" },
    pattern = "$nvcc-location",
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/scss/package.json#L43
  ["$node-sass"] = {
    fileLocation = "absolute",
    pattern = {
      {
        regexp = "^{$",
      },
      {
        regexp = '\\s*"status":\\s\\d+,',
      },
      {
        regexp = '\\s*"file":\\s"(.*)",',
        file = 1,
      },
      {
        regexp = '\\s*"line":\\s(\\d+),',
        line = 1,
      },
      {
        regexp = '\\s*"column":\\s(\\d+),',
        column = 1,
      },
      {
        regexp = '\\s*"message":\\s"(.*)",',
        message = 1,
      },
      {
        regexp = '\\s*"formatted":\\s(.*)',
      },
      {
        regexp = "^}$",
      },
    },
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/less/package.json#L39
  ["$lessc"] = {
    fileLocation = "absolute",
    pattern = {
      regexp = "(.*)\\sin\\s(.*)\\son line\\s(\\d+),\\scolumn\\s(\\d+)",
      message = 1,
      file = 2,
      line = 3,
      column = 4,
    },
  },
  -- from https://github.com/microsoft/vscode-cpptools/blob/main/Extension/package.json#L76
  ["$gcc"] = {
    fileLocation = { "autoDetect", "${cwd}" },
    pattern = {
      regexp = "^(.*?) =(\\d+):(\\d*):?\\s+(?:fatal\\s+)?(warning|error):\\s+(.*)$",
      vim_regexp = "\\v^(.{-}):(\\d+):(\\d*):?\\s+%(fatal\\s+)?(warning|error):\\s+(.*)$",
      file = 1,
      line = 2,
      column = 3,
      severity = 4,
      message = 5,
    },
  },
}

---@param name string
---@param defn table
M.register_pattern = function(name, defn)
  if name:find("$", nil, true) ~= 1 then
    log.warn("Pattern '%s' should start with '$'", name)
    name = "$" .. name
  end
  default_patterns[name] = defn
end

---@param name string
---@param defn table
M.register_problem_matcher = function(name, defn)
  if name:find("$", nil, true) ~= 1 then
    log.warn("Problem matcher '%s' should start with '$'", name)
    name = "$" .. name
  end
  default_matchers[name] = defn
end

local severity_to_type = {
  error = "E",
  warning = "W",
  info = "I",
}
local match_names = {
  "file",
  "location",
  "line",
  "column",
  "character",
  "endLine",
  "endColumn",
  "severity",
  "code",
  "message",
}

---@param n string
---@return nil|number
local function convert_number(n)
  return tonumber(n)
end

---Convert VS Code match names to keys in a vim.quickfix.entry
---@param name string
---@return overseer.ParseField
local function convert_match_name(name)
  if name == "file" then
    return "filename"
  elseif name == "location" then
    return {
      "lnum",
      function(value, item)
        local lnum, col, end_lnum, end_col = unpack(vim.split(value, ","))
        item.col = tonumber(col)
        item.end_lnum = tonumber(end_lnum)
        item.end_col = tonumber(end_col)
        return tonumber(lnum)
      end,
    }
  elseif name == "line" then
    return { "lnum", convert_number }
  elseif name == "column" then
    return { "col", convert_number }
  elseif name == "character" then
    return { "col", convert_number }
  elseif name == "endLine" then
    return { "end_lnum", convert_number }
  elseif name == "endColumn" then
    return { "end_col", convert_number }
  elseif name == "severity" then
    return "type"
  elseif name == "code" then
    -- TODO we don't have a use for the code at the moment
    return "code"
  elseif name == "message" then
    return "text"
  else
    error(string.format("Unknown match name %s", name))
  end
end

---@param pattern string|table
---@return overseer.MatchFn
local function pattern_to_match_fn(pattern)
  if type(pattern) == "string" then
    return parselib.make_regex_match_fn("\\v" .. pattern)
  elseif pattern.lua_pat then
    return parselib.make_lua_match_fn(pattern.lua_pat)
  elseif pattern.vim_regexp then
    return parselib.make_regex_match_fn(pattern.vim_regexp)
  else
    -- Fall back to trying to auto-convert the JS regex to a vim regex
    return parselib.make_regex_match_fn("\\v" .. pattern.regexp)
  end
end

---@param pattern? table|string
---@return nil|overseer.TestFn
local function pattern_to_test_fn(pattern)
  if not pattern then
    return nil
  end
  return parselib.match_to_test_fn(pattern_to_match_fn(pattern))
end

---@param pattern table
---@param opts {append?: boolean, qf_type?: string, file_convert?: fun(file: string): string}
---@return overseer.ParseFn
local function pattern_to_parse_fn(pattern, opts)
  ---@type overseer.ParseField[]
  local args = {}
  local full_line_key
  local max_arg = 0
  for _, v in ipairs(match_names) do
    ---@type integer
    local i = pattern[v] ---@diagnostic disable-line: assign-type-mismatch
    if not i then
      i = 0
    end
    if i == 0 then
      -- Technically the schema supports using 0 for other fields, but it only
      -- really makes sense for the message
      if v == "message" then
        full_line_key = "text"
      end
    else
      if i > max_arg then
        max_arg = i
      end
      args[i] = convert_match_name(v)
    end
  end
  -- We have to fill in the holes, otherwise this won't be treated as a
  -- list-like table
  for i = 1, max_arg do
    if not args[i] then
      args[i] = "_"
    end
  end

  local match = pattern_to_match_fn(pattern)
  local extract = parselib.make_parse_fn(match, args)

  return function(line)
    local item = extract(line)
    if item then
      if not item.type then
        item.type = opts.qf_type
      end
      if full_line_key then
        item[full_line_key] = line
      end
      if opts.file_convert and item.filename then
        item.filename = opts.file_convert(item.filename)
      end
    end
    return item
  end
end

---@param patterns table[]
---@param opts {append?: boolean, qf_type?: string, file_convert?: fun(file: string): string}
---@return overseer.OutputParser
local function patterns_to_parser(patterns, opts)
  local parse_fns = {}
  for _, pattern in ipairs(patterns) do
    local parse_fn = pattern_to_parse_fn(pattern, opts)
    table.insert(parse_fns, parse_fn)
  end
  local loop_last = patterns[#patterns].loop
  local idx = 1
  local pending_item = {}
  local result = {}

  ---@type overseer.OutputParser
  return {
    parse = function(self, line)
      local item = parse_fns[idx](line)
      local is_last_fn = idx == #parse_fns
      if item then
        if is_last_fn then
          item = vim.tbl_extend("keep", item, pending_item)
          table.insert(result, item)
          if not loop_last then
            idx = 1
          end
        else
          pending_item = vim.tbl_extend("force", pending_item, item)
          idx = idx + 1
        end
      else
        -- If we are in the middle of the parse funcs and the match fails, reset and try matching
        -- again starting from the first function
        if idx > 1 then
          idx = 1
          pending_item = {}
          self:parse(line)
        end
      end
    end,
    get_result = function()
      return { diagnostics = result }
    end,
    reset = function()
      idx = 1
      pending_item = {}
      result = {}
    end,
  }
end

M.resolve_problem_matcher = function(problem_matcher)
  if not problem_matcher then
    return nil
  end
  if type(problem_matcher) == "string" then
    local pm = default_matchers[problem_matcher]
    if not pm then
      log.error("Could not find problem matcher '%s'", problem_matcher)
    end
    return M.resolve_problem_matcher(pm)
  elseif vim.islist(problem_matcher) then
    local children = {}
    for _, v in ipairs(problem_matcher) do
      local pm = M.resolve_problem_matcher(v)
      if pm then
        table.insert(children, pm)
      end
    end
    if vim.tbl_isempty(children) then
      return nil
    end
    return children
  end
  if problem_matcher.base then
    if default_matchers[problem_matcher.base] then
      return vim.tbl_deep_extend("keep", problem_matcher, default_matchers[problem_matcher.base])
    else
      log.error("Could not find problem matcher '%s'", problem_matcher.base)
      return nil
    end
  end
  return problem_matcher
end

-- Process file name based on "fileLocation"
-- Valid: "absolute", "relative", "autoDetect", ["relative", "path value"], ["autoDetect", "path value"]
local function file_converter(file_loc, precalculated_vars)
  local typ = type(file_loc) == "table" and file_loc[1] or file_loc
  assert(
    vim.tbl_contains({ "absolute", "relative", "autoDetect" }, typ),
    "Unsupported fileLocation: " .. typ
  )
  -- TODO: passing params to replace_vars not supported yet
  local rel_path = type(file_loc) == "table"
      and variables.replace_vars(file_loc[2], {}, precalculated_vars)
    or vim.fn.getcwd()

  ---@param file string
  return function(file)
    if typ == "absolute" then
      return file
    else -- relative/autoDetect
      local rel = vim.fn.fnamemodify(rel_path .. "/" .. file, ":p")
      if typ == "autoDetect" and vim.fn.filereadable(rel) ~= 1 then
        return file
      end
      return rel
    end
  end
end

---@param parser overseer.OutputParser
---@param background? table
local function wrap_background_parser(parser, background)
  if not background then
    return parser
  end
  return parselib.wrap_background_parser(parser, {
    active_on_start = background.activeOnStart,
    start_fn = pattern_to_test_fn(background.beginsPattern),
    end_fn = pattern_to_test_fn(background.endsPattern),
  })
end

---@param problem_matcher? table
---@param precalculated_vars? table
---@return nil|overseer.OutputParser
M.get_parser_from_problem_matcher = function(problem_matcher, precalculated_vars)
  problem_matcher = M.resolve_problem_matcher(problem_matcher)
  if not problem_matcher then
    return nil
  end

  if vim.islist(problem_matcher) then
    -- this is a list of problem matchers
    local background
    local all_parsers = {}
    for _, v in ipairs(problem_matcher) do
      local parser = M.get_parser_from_problem_matcher(v, precalculated_vars)
      if parser then
        assert(parser, "Failed to create overseer parser from VS Code problem matcher")
        table.insert(all_parsers, parser)
        if v.background then
          background = v.background
        end
      end
    end
    return wrap_background_parser(parselib.combine_parsers(all_parsers), background)
  end

  local qf_type = severity_to_type[problem_matcher.severity]
  local pattern = problem_matcher.pattern
  local background = problem_matcher.background
  local convert = problem_matcher.fileLocation
    and file_converter(problem_matcher.fileLocation, precalculated_vars)
  if type(pattern) == "string" then
    if default_patterns[pattern] then
      pattern = vim.deepcopy(default_patterns[pattern])
    else
      log.error("Could not find problem matcher pattern '%s'", pattern)
      return nil
    end
  end

  local ret
  if vim.islist(pattern) then
    ret = patterns_to_parser(pattern, { qf_type = qf_type, file_convert = convert })
  else
    local parse_fn = pattern_to_parse_fn(pattern, { qf_type = qf_type, file_convert = convert })
    ret = parselib.make_parser(parse_fn)
  end

  return wrap_background_parser(ret, background)
end

---This is used for generating documentation
---@private
M.list_patterns = function()
  local patterns = vim.tbl_keys(default_patterns)
  table.sort(patterns)
  return patterns
end

---This is used for generating documentation
---@private
M.list_problem_matchers = function()
  local matchers = vim.tbl_keys(default_matchers)
  table.sort(matchers)
  return matchers
end

return M
