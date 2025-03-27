local files = require("overseer.files")
local log = require("overseer.log")
local parser = require("overseer.parser")
local problem_matcher = require("overseer.template.vscode.problem_matcher")

---@type overseer.ComponentFileDefinition
return {
  desc = "Parses task output and sets task result",
  params = {
    parser = {
      desc = "Parser definition to extract values from output",
      type = "opaque",
      optional = true,
      order = 1,
    },
    problem_matcher = {
      desc = "VS Code-style problem matcher",
      type = "opaque",
      optional = true,
      order = 2,
    },
    relative_file_root = {
      desc = "Relative filepaths will be joined to this root (instead of task cwd)",
      optional = true,
      default_from_task = true,
      order = 3,
    },
    precalculated_vars = {
      desc = "Precalculated VS Code task variables",
      long_desc = "Tasks that are started from the VS Code provider precalculate certain interpolated variables (e.g. ${workspaceFolder}). We pass those in as params so they will remain stable even if Neovim's state changes in between creating and running (or restarting) the task.",
      type = "opaque",
      optional = true,
      order = 4,
    },
  },
  constructor = function(params)
    if params.parser and params.problem_matcher then
      log.warn("on_output_parse: cannot specify both 'parser' and 'problem_matcher'")
    elseif not params.parser and not params.problem_matcher then
      log.error("on_output_parse: one of 'parser', 'problem_matcher' is required")
      return {}
    end
    local parser_defn = params.parser
    if params.problem_matcher then
      local pm = problem_matcher.resolve_problem_matcher(params.problem_matcher)
      if pm then
        parser_defn = problem_matcher.get_parser_from_problem_matcher(pm, params.precalculated_vars)
        if parser_defn then
          parser_defn = { diagnostics = parser_defn }
        end
      end
    end
    if not parser_defn then
      return {}
    end
    return {
      on_init = function(self, task)
        self.parser = parser.new(parser_defn)
        self.parser_sub = function(key, result)
          -- TODO reconsider this API for dispatching partial results
          -- task:dispatch("on_stream_result", key, result)
        end
        self.parser:subscribe("new_item", self.parser_sub)
        self.set_results_sub = function()
          local result = self.parser:get_result()
          if result.diagnostics then
            -- Ensure that all relative filenames are rooted at the task cwd, not vim's current cwd
            for _, diag in ipairs(result.diagnostics) do
              if diag.filename and not files.is_absolute(diag.filename) then
                diag.filename =
                  vim.fs.joinpath(params.relative_file_root or task.cwd, diag.filename)
              end
            end
          end
          task:set_result(result)
        end
        self.parser:subscribe("set_results", self.set_results_sub)
      end,
      on_dispose = function(self)
        if self.parser_sub then
          self.parser:unsubscribe("new_item", self.parser_sub)
          self.parser_sub = nil
        end
        if self.set_results_sub then
          self.parser:unsubscribe("set_results", self.set_results_sub)
          self.set_results_sub = nil
        end
      end,
      on_reset = function(self)
        self.parser:reset()
      end,
      on_output_lines = function(self, task, lines)
        self.parser:ingest(lines)
      end,
      on_pre_result = function(self, task)
        return self.parser:get_result()
      end,
    }
  end,
}
