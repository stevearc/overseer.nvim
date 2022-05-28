local parser = require("overseer.parser")
local M = {}

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
      function(value, item)
        local lnum, col, end_lnum, end_col = unpack(vim.split(value, ","))
        item.col = tonumber(col)
        item.end_lnum = tonumber(end_lnum)
        item.end_col = tonumber(end_col)
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
    return {
      "type",
      function(value)
        if value:lower():match("^w") then
          return "W"
        elseif value:lower():match("^i") then
          return "I"
        else
          return "E"
        end
      end,
    }
  elseif name == "code" then
    -- TODO this won't do anything
    return "code"
  elseif name == "message" then
    return "text"
  else
    error(string.format("Unknown match name %s", name))
  end
end
M.get_parser_from_problem_matcher = function(problem_matcher)
  if not problem_matcher then
    return nil
  end
  if type(problem_matcher) == "string" then
    -- TODO support builtin matchers
    return nil
  end
  if problem_matcher.base then
    -- TODO support builtin matchers
    return nil
  end
  -- NOTE: we ignore matcher.owner
  -- TODO: support matcher.fileLocation
  local qf_type = severity_to_type[problem_matcher.severity]
  local pattern = problem_matcher.pattern
  if not pattern then
    return nil
  end
  if type(pattern) == "string" then
    -- TODO support builtin matchers
    return nil
  end
  if vim.tbl_islist(pattern) then
    -- FIXME support multiline problem matcher
  else
    local args = {}
    local full_line_key
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
        args[i] = convert_match_name(v)
      end
    end
    local opts = {
      regex = true,
      append = function(results, item, ctx)
        if not item.type then
          item.type = qf_type
        end
        if full_line_key then
          item[full_line_key] = ctx.line
        end
        table.insert(results, item)
      end,
    }
    return {
      parser.extract(opts, "\\v" .. pattern.regexp, unpack(args)),
    }
  end

  return nil
end

return M
