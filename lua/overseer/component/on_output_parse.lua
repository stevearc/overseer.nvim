local parser = require("overseer.parser")

return {
  desc = "Parses task output and sets task result",
  params = {
    parser = {
      desc = "Parser definition to extract values from output",
      type = "opaque",
    },
  },
  constructor = function(params)
    return {
      on_init = function(self, task)
        self.parser = parser.new(params.parser)
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
