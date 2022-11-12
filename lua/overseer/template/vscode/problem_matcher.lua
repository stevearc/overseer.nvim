local parser_lib = require("overseer.parser.lib")
local log = require("overseer.log")
local M = {}

-- Taken from https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/tasks/common/problemMatcher.ts#L1207
local default_patterns = {
  ["$msCompile"] = {
    -- regexp: /^(?:\s+\d+>)?(\S.*)\((\d+|\d+,\d+|\d+,\d+,\d+,\d+)\)\s*:\s+(error|warning|info)\s+(\w+\d+)\s*:\s*(.*)$/,
    regexp = "^(\\s+\\d+>)?(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\)\\s*:\\s+(error|warning|info)\\s+(\\w+\\d+)\\s*:\\s*(.*)$",
    kind = "location",
    file = 2,
    location = 3,
    severity = 4,
    code = 5,
    message = 6,
  },
  ["$gulp-tsc"] = {
    -- regexp: /^([^\s].*)\((\d+|\d+,\d+|\d+,\d+,\d+,\d+)\):\s+(\d+)\s+(.*)$/,
    regexp = "^([^[:space:]].*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(\\d+)\\s+(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    code = 3,
    message = 4,
  },
  ["$cpp"] = {
    -- regexp: /^(\S.*)\((\d+|\d+,\d+|\d+,\d+,\d+,\d+)\):\s+(error|warning|info)\s+(C\d+)\s*:\s*(.*)$/,
    regexp = "^(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(error|warning|info)\\s+(C\\d+)\\s*:\\s*(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    code = 4,
    message = 5,
  },
  ["$csc"] = {
    -- regexp: /^(\S.*)\((\d+|\d+,\d+|\d+,\d+,\d+,\d+)\):\s+(error|warning|info)\s+(CS\d+)\s*:\s*(.*)$/,
    regexp = "^(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(error|warning|info)\\s+(CS\\d+)\\s*:\\s*(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    code = 4,
    message = 5,
  },
  ["$vb"] = {
    -- regexp: /^(\S.*)\((\d+|\d+,\d+|\d+,\d+,\d+,\d+)\):\s+(error|warning|info)\s+(BC\d+)\s*:\s*(.*)$/,
    regexp = "^(\\S.*)\\((\\d+|\\d+,\\d+|\\d+,\\d+,\\d+,\\d+)\\):\\s+(error|warning|info)\\s+(BC\\d+)\\s*:\\s*(.*)$",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    code = 4,
    message = 5,
  },
  ["$lessCompile"] = {
    -- regexp: /^\s*(.*) in file (.*) line no. (\d+)$/,
    regexp = "^\\s*(.*) in file (.*) line no. (\\d+)$",
    kind = "location",
    message = 1,
    file = 2,
    line = 3,
  },
  ["$jshint"] = {
    -- regexp: /^(.*):\s+line\s+(\d+),\s+col\s+(\d+),\s(.+?)(?:\s+\((\w)(\d+)\))?$/,
    regexp = "^(.*):\\s+line\\s+(\\d+),\\s+col\\s+(\\d+),\\s(.+?)(\\s+\\((\\w)(\\d+)\\))?$",
    kind = "location",
    file = 1,
    line = 2,
    character = 3,
    message = 4,
    severity = 6,
    code = 7,
  },
  ["$jshint-stylish"] = {
    {
      -- regexp: /^(.+)$/,
      regexp = "^(.+)$",
      kind = "location",
      file = 1,
    },
    {
      -- regexp: /^\s+line\s+(\d+)\s+col\s+(\d+)\s+(.+?)(?:\s+\((\w)(\d+)\))?$/,
      regexp = "^\\s+line\\s+(\\d+)\\s+col\\s+(\\d+)\\s+(.+?)(\\s+\\((\\w)(\\d+)\\))?$",
      line = 1,
      character = 2,
      message = 3,
      severity = 5,
      code = 6,
      loop = true,
    },
  },
  ["$eslint-compact"] = {
    -- regexp: /^(.+):\sline\s(\d+),\scol\s(\d+),\s(Error|Warning|Info)\s-\s(.+)\s\((.+)\)$/,
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
      -- regexp: /^((?:[a-zA-Z]:)*[./\\]+.*?)$/,
      regexp = "^(([a-zA-Z]:)*[./\\\\]+.*?)$",
      kind = "location",
      file = 1,
    },
    {
      -- regexp: /^\s+(\d+):(\d+)\s+(error|warning|info)\s+(.+?)(?:\s\s+(.*))?$/,
      regexp = "^\\s+(\\d+):(\\d+)\\s+(error|warning|info)\\s+(.+?)(\\s\\s+(.*))?$",
      line = 1,
      character = 2,
      severity = 3,
      message = 4,
      code = 6,
      loop = true,
    },
  },
  ["$go"] = {
    -- regexp: /^([^:]*: )?((.:)?[^:]*):(\d+)(:(\d+))?: (.*)$/,
    regexp = "^([^:]*: )?((.:)?[^:]*):(\\d+)(:(\\d+))?: (.*)$",
    kind = "location",
    file = 2,
    line = 4,
    character = 6,
    message = 7,
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/typescript-language-features/package.json#L1396
  ["$tsc"] = {
    -- regexp: "^([^\\s].*)[\\(:](\\d+)[,:](\\d+)(?:\\):\\s+|\\s+-\\s+)(error|warning|info)\\s+TS(\\d+)\\s*:\\s*(.*)$",
    regexp = "^([^[:space:]].*)[\\(:](\\d+)[,:](\\d+)(\\):\\s+|\\s+-\\s+)(error|warning|info)\\s+TS(\\d+)\\s*:\\s*(.*)$",
    file = 1,
    line = 2,
    column = 3,
    severity = 5,
    code = 6,
    message = 7,
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/cpp/package.json#L95
  ["$nvcc-location"] = {
    -- regexp: "^(.*)\\((\\d+)\\):\\s+(warning|error):\\s+(.*)",
    regexp = "^(.*)\\((\\d+)\\):\\s+(warning|error):\\s+(.*)",
    kind = "location",
    file = 1,
    location = 2,
    severity = 3,
    message = 4,
  },
}

local default_matchers = {
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
        -- "regexp": "^\\s*(?:message TS6032:|\\[?\\D*.{1,2}[:.].{1,2}[:.].{1,2}\\D*(├\\D*\\d{1,2}\\D+┤)?(?:\\]| -)) File change detected\\. Starting incremental compilation\\.\\.\\."
        regexp = "^\\s*(message TS6032:|\\[?\\D*.{1,2}[:.].{1,2}[:.].{1,2}\\D*(├\\D*\\d{1,2}\\D+┤)?(\\]| -)) File change detected\\. Starting incremental compilation\\.\\.\\.",
      },
      endsPattern = {
        -- "regexp": "^\\s*(?:message TS6042:|\\[?\\D*.{1,2}[:.].{1,2}[:.].{1,2}\\D*(├\\D*\\d{1,2}\\D+┤)?(?:\\]| -)) (?:Compilation complete\\.|Found \\d+ errors?\\.) Watching for file changes\\."
        regexp = "^\\s*(message TS6042:|\\[?\\D*.{1,2}[:.].{1,2}[:.].{1,2}\\D*(├\\D*\\d{1,2}\\D+┤)?(\\]| -)) (Compilation complete\\.|Found \\d+ errors?\\.) Watching for file changes\\.",
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
        -- "regexp": "^{$"
        regexp = "^{$",
      },
      {
        -- "regexp": "\\s*\"status\":\\s\\d+,"
        regexp = '\\s*"status":\\s\\d+,',
      },
      {
        -- "regexp": "\\s*\"file\":\\s\"(.*)\",",
        regexp = '\\s*"file":\\s"(.*)",',
        file = 1,
      },
      {
        -- "regexp": "\\s*\"line\":\\s(\\d+),",
        regexp = '\\s*"line":\\s(\\d+),',
        line = 1,
      },
      {
        -- "regexp": "\\s*\"column\":\\s(\\d+),",
        regexp = '\\s*"column":\\s(\\d+),',
        column = 1,
      },
      {
        -- "regexp": "\\s*\"message\":\\s\"(.*)\",",
        regexp = '\\s*"message":\\s"(.*)",',
        message = 1,
      },
      {
        -- "regexp": "\\s*\"formatted\":\\s(.*)"
        regexp = '\\s*"formatted":\\s(.*)',
      },
      {
        -- "regexp": "^}$"
        regexp = "^}$",
      },
    },
  },
  -- from https://github.com/microsoft/vscode/blob/main/extensions/less/package.json#L39
  ["$lessc"] = {
    fileLocation = "absolute",
    pattern = {
      -- "regexp": "(.*)\\sin\\s(.*)\\son line\\s(\\d+),\\scolumn\\s(\\d+)",
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
      -- regexp = "^(.*?):(\\d+):(\\d*):?\\s+(?:fatal\\s+)?(warning|error):\\s+(.*)$",
      regexp = "^([^:]*):(\\d+):(\\d*):?\\s+(fatal\\s+)?(warning|error):\\s+(.*)$",
      file = 1,
      line = 2,
      column = 3,
      severity = 5,
      message = 6,
    },
  },
}

---@param name string
---@param defn table
M.register_pattern = function(name, defn)
  if name:find("$", nil, true) ~= 1 then
    name = "$" .. name
  end
  default_patterns[name] = defn
end

---@param name string
---@param defn table
M.register_problem_matcher = function(name, defn)
  if name:find("$", nil, true) ~= 1 then
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
  "endLine",
  "endColumn",
  "severity",
  "code",
  "message",
}
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
    return "lnum"
  elseif name == "column" then
    return "col"
  elseif name == "endLine" then
    return "end_lnum"
  elseif name == "endColumn" then
    return "end_col"
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
    local i = pattern[v]
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
    regex = true,
    append = opts.append,
    postprocess = function(item, ctx)
      if not item.type then
        item.type = opts.qf_type
      end
      if full_line_key then
        item[full_line_key] = ctx.line
      end
    end,
  }
  local extract = { "extract", extract_opts, "\\v" .. pattern.regexp, unpack(args) }
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
    local pat = "\\v" .. pattern
    return function(line)
      return vim.fn.match(line, pat) ~= -1
    end
  else
    return pattern_to_test(pattern.regexp)
  end
end

local function add_background(background, child)
  if not background then
    return child
  end
  return parser_lib.watcher_output(
    pattern_to_test(background.beginsPattern),
    pattern_to_test(background.endsPattern),
    child,
    {
      active_on_start = background.activeOnStart,
    }
  )
end

M.get_parser_from_problem_matcher = function(problem_matcher)
  if not problem_matcher then
    return nil
  end
  if vim.tbl_islist(problem_matcher) then
    local background
    local children = {}
    for _, v in ipairs(problem_matcher) do
      vim.list_extend(children, M.get_parser_from_problem_matcher(v))
      if v.background then
        background = v.background
      end
    end
    local ret = { "parallel", { break_on_first_failure = false }, unpack(children) }
    return add_background(background, ret)
  end

  -- NOTE: we ignore matcher.owner
  -- TODO: support matcher.fileLocation
  local qf_type = severity_to_type[problem_matcher.severity]
  local pattern = problem_matcher.pattern
  local background = problem_matcher.background
  local ret
  if vim.tbl_islist(pattern) then
    ret = { "sequence" }
    for i, v in ipairs(pattern) do
      local append = i == #pattern
      local parse_node = convert_pattern(v, { append = append, qf_type = qf_type })
      if not parse_node then
        return nil
      end
      table.insert(ret, parse_node)
    end
  else
    local parse_node = convert_pattern(pattern, { qf_type = qf_type })
    if parse_node then
      ret = parse_node
    else
      return nil
    end
  end
  return add_background(background, ret)
end

return M
