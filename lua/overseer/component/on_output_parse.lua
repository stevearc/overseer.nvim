local files = require("overseer.files")
local log = require("overseer.log")
local parselib = require("overseer.parselib")
local problem_matcher = require("overseer.vscode.problem_matcher")

---@param cwd string
---@param result table
---@return table
local function fix_relative_filenames(cwd, result)
  if result.diagnostics then
    -- Ensure that all relative filenames are rooted at the task cwd, not vim's current cwd
    for _, diag in ipairs(result.diagnostics) do
      if diag.filename and not files.is_absolute(diag.filename) then
        diag.filename = vim.fs.joinpath(cwd, diag.filename)
      end
    end
  end
  return result
end

---@type overseer.ComponentFileDefinition
return {
  desc = "Parses task output and sets task result",
  params = {
    parser = {
      desc = "Parse function or overseer.OutputParser",
      long_desc = "This can be a function that takes a line of output and (optionally) returns a quickfix-list item (see :help |setqflist-what|). For more complex parsing, this should be a class of type overseer.OutputParser.",
      type = "opaque",
      optional = true,
      order = 1,
    },
    problem_matcher = {
      desc = "VS Code-style problem matcher",
      long_desc = "Only one of 'parser', 'problem_matcher', or 'errorformat' is allowed.",
      type = "opaque",
      optional = true,
      order = 2,
    },
    errorformat = {
      desc = "Errorformat string",
      long_desc = "Only one of 'parser', 'problem_matcher', or 'errorformat' is allowed.",
      type = "opaque",
      optional = true,
      order = 3,
    },
    precalculated_vars = {
      desc = "Precalculated VS Code task variables",
      long_desc = "Tasks that are started from the VS Code provider precalculate certain interpolated variables (e.g. ${workspaceFolder}). We pass those in as params so they will remain stable even if Neovim's state changes in between creating and running (or restarting) the task.",
      type = "opaque",
      optional = true,
      order = 4,
    },
    relative_file_root = {
      desc = "Relative filepaths will be joined to this root (instead of task cwd)",
      optional = true,
      default_from_task = true,
      order = 5,
    },
  },
  constructor = function(params)
    local p = { params.parser, params.problem_matcher, params.errorformat }
    local num_parse_opts = #vim.tbl_keys(p)
    if num_parse_opts == 0 then
      log.error("on_output_parse: one of 'parser', 'problem_matcher', 'errorformat' is required")
      return {}
    elseif num_parse_opts > 1 then
      log.error(
        "on_output_parse: only one of 'parser', 'problem_matcher', 'errorformat' is allowed"
      )
      return {}
    end

    local parser
    if params.problem_matcher then
      parser = problem_matcher.get_parser_from_problem_matcher(
        params.problem_matcher,
        params.precalculated_vars
      )
    elseif type(params.parser) == "function" then
      parser = parselib.make_parser(params.parser)
    elseif params.parser then
      parser = params.parser
    else
      parser = parselib.parser_from_errorformat(params.errorformat)
    end
    if not parser then
      log.error(
        "Could not create output parser from %s",
        params.problem_matcher or params.parser or params.errorformat
      )
      return {}
    end
    ---@cast parser overseer.OutputParser

    local version = parser.result_version
    return {
      on_reset = function(self)
        parser:reset()
        version = parser.result_version
      end,
      on_output_lines = function(self, task, lines)
        for _, line in ipairs(lines) do
          parser:parse(line)
        end
        if version ~= parser.result_version then
          task:set_result(
            fix_relative_filenames(params.relative_file_root or task.cwd, parser:get_result())
          )
          version = parser.result_version
        end
      end,
      on_pre_result = function(self, task)
        return fix_relative_filenames(params.relative_file_root or task.cwd, parser:get_result())
      end,
    }
  end,
}
