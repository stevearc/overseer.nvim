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
        local cb = function(key, result)
          -- TODO reconsider this API for dispatching partial results
          -- task:dispatch("on_stream_result", key, result)
        end
        self.parser:subscribe(cb)
        self.parser_sub = cb
      end,
      on_dispose = function(self)
        if self.parser_sub then
          self.parser:unsubscribe(self.parser_sub)
          self.parser_sub = nil
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
