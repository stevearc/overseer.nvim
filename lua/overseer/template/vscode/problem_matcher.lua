local parser_lib = require("overseer.parser.lib")
local log = require("overseer.log")
local variables = require("overseer.template.vscode.variables")
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
    vim_regexp = "\\v^(.*):\\s+line\\s+(\\d+),\\s+col\\s+(\\d+),\\s(.+?)%(\\s+\\((\\w)(\\d+)\\))?$",
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
      vim_regexp = "\\v^\\s+line\\s+(\\d+)\\s+col\\s+(\\d+)\\s+(.+?)%(\\s+\\((\\w)(\\d+)\\))?$",
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
      vim_regexp = "\\v^(%([a-zA-Z]:)*[./\\\\]+.*?)$",
      kind = "location",
      file = 1,
    },
    {
      regexp = "^\\s+(\\d+):(\\d+)\\s+(error|warning|info)\\s+(.+?)(?:\\s\\s+(.*))?$",
      vim_regexp = "\\v^\\s+(\\d+):(\\d+)\\s+(error|warning|info)\\s+(.+?)%(\\s\\s+(.*))?$",
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
    log:warn("Pattern '%s' should start with '$'", name)
    name = "$" .. name
  end
  default_patterns[name] = defn
end

---@param name string
---@param defn table
M.register_problem_matcher = function(name, defn)
  if name:find("$", nil, true) ~= 1 then
    log:warn("Problem matcher '%s' should start with '$'", name)
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
local function num_field(name)
  return {
    name,
    function(value, ctx)
      return tonumber(value)
    end,
  }
end
local function convert_match_name(name)
  if name == "file" then
    return "filename"
  elseif name == "location" then
    return {
      "lnum",
      function(value, ctx)
        local lnum, col, end_lnum, end_col = unpack(vim.split(value, ","))
        ctx.item.col = tonumber(col)
        ctx.item.end_lnum = tonumber(end_lnum)
        ctx.item.end_col = tonumber(end_col)
        return tonumber(lnum)
      end,
    }
  elseif name == "line" then
    return num_field("lnum")
  elseif name == "column" then
    return num_field("col")
  elseif name == "character" then
    return num_field("col")
  elseif name == "endLine" then
    return num_field("end_lnum")
  elseif name == "endColumn" then
    return num_field("end_col")
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

local function convert_pattern(pattern, opts)
  opts = opts or {}
  if type(pattern) == "string" then
    if default_patterns[pattern] then
      pattern = vim.deepcopy(default_patterns[pattern])
    else
      log:error("Could not find problem matcher pattern '%s'", pattern)
      return nil
    end
  end
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
  local extract_opts = {
    append = opts.append,
    postprocess = function(item, ctx)
      if not item.type then
        item.type = opts.qf_type
      end
      if full_line_key then
        item[full_line_key] = ctx.line
      end
      if opts.file_convert and item.filename then
        item.filename = opts.file_convert(item.filename)
      end
    end,
  }
  local extract_pat
  if pattern.lua_pat then
    extract_pat = pattern.lua_pat
  elseif pattern.vim_regexp then
    extract_pat = pattern.vim_regexp
    extract_opts.regex = true
  else
    -- Fall back to trying to auto-convert the JS regex to a vim regex
    extract_pat = "\\v" .. pattern.regexp
    extract_opts.regex = true
  end
  local extract = { "extract", extract_opts, extract_pat, unpack(args) }
  if pattern.loop then
    return { "set_defaults", { "loop", extract } }
  end
  return extract
end

M.resolve_problem_matcher = function(problem_matcher)
  if not problem_matcher then
    return nil
  end
  if type(problem_matcher) == "string" then
    local pm = default_matchers[problem_matcher]
    if not pm then
      log:error("Could not find problem matcher '%s'", problem_matcher)
    end
    return M.resolve_problem_matcher(pm)
  elseif vim.tbl_islist(problem_matcher) then
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
      log:error("Could not find problem matcher '%s'", problem_matcher.base)
      return nil
    end
  end
  return problem_matcher
end

local function pattern_to_test(pattern)
  if not pattern then
    return nil
  elseif type(pattern) == "string" then
    return { { regex = true }, "\\v" .. pattern }
  else
    if pattern.lua_pat then
      return pattern.lua_pat
    elseif pattern.vim_regexp then
      return { { regex = true }, pattern.vim_regexp }
    else
      return pattern_to_test(pattern.regexp)
    end
  end
end

local function add_background(background, child)
  if not background then
    return child
  end
  return parser_lib.watcher_output(
    assert(pattern_to_test(background.beginsPattern)),
    assert(pattern_to_test(background.endsPattern)),
    child,
    {
      active_on_start = background.activeOnStart,
    }
  )
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

---@param problem_matcher table
---@param precalculated_vars? table
M.get_parser_from_problem_matcher = function(problem_matcher, precalculated_vars)
  if not problem_matcher then
    return nil
  end
  if vim.tbl_islist(problem_matcher) then
    local background
    local children = {}
    for _, v in ipairs(problem_matcher) do
      local parser = M.get_parser_from_problem_matcher(v, precalculated_vars)
      assert(parser, "Failed to create overseer parser from VS Code problem matcher")
      local is_parser = type(parser[1]) == "string"
      if is_parser then
        table.insert(children, parser)
      else
        vim.list_extend(children, parser)
      end
      if v.background then
        background = v.background
      end
    end
    local ret = { "parallel", { break_on_first_failure = false }, unpack(children) }
    return add_background(background, ret)
  end

  -- NOTE: we ignore matcher.owner
  local qf_type = severity_to_type[problem_matcher.severity]
  local pattern = problem_matcher.pattern
  local background = problem_matcher.background
  local convert = problem_matcher.fileLocation
    and file_converter(problem_matcher.fileLocation, precalculated_vars)
  local ret
  if vim.tbl_islist(pattern) then
    ret = { "sequence" }
    for i, v in ipairs(pattern) do
      local append = i == #pattern
      local parse_node =
        convert_pattern(v, { append = append, qf_type = qf_type, file_convert = convert })
      if not parse_node then
        return nil
      end
      table.insert(ret, parse_node)
    end
  else
    local parse_node = convert_pattern(pattern, { qf_type = qf_type, file_convert = convert })
    if parse_node then
      ret = parse_node
    else
      return nil
    end
  end
  return add_background(background, ret)
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
