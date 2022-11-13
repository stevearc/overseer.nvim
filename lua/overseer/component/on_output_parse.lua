local log = require("overseer.log")
local parser = require("overseer.parser")
local problem_matcher = require("overseer.template.vscode.problem_matcher")

return {
  desc = "Parses task output and sets task result",
  params = {
    parser = {
      desc = "Parser definition to extract values from output",
      type = "opaque",
      optional = true,
    },
    problem_matcher = {
      desc = "VS Code-style problem matcher",
      type = "opaque",
      optional = true,
    },
  },
  constructor = function(params)
    if params.parser and params.problem_matcher then
      log:warn("on_output_parse: cannot specify both 'parser' and 'problem_matcher'")
    end
    local parser_defn = params.parser
    if params.problem_matcher then
      local pm = problem_matcher.resolve_problem_matcher(params.problem_matcher)
      parser_defn = problem_matcher.get_parser_from_problem_matcher(pm)
      if parser_defn then
        parser_defn = { diagnostics = parser_defn }
      end
    end
    if not parser_defn then
      log:error("on_output_parse: one of 'parser', 'problem_matcher' is required")
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
          task:set_result(self.parser:get_result())
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
