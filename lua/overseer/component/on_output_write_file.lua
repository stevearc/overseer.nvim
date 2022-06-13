return {
  description = "Write task output to a file",
  params = {
    filename = {},
  },
  constructor = function(params)
    return {
      on_init = function(self)
        self.output_file = assert(io.open(params.filename, "w"))
      end,
      on_reset = function(self)
        self.output_file:close()
        self.output_file = assert(io.open(params.filename, "w"))
      end,
      on_output = function(self, task, data)
        for i, chunk in ipairs(data) do
          if i == 0 and chunk == "" then
            self.output_file:write("\n")
          elseif i > 0 then
            self.output_file:write("\n")
          end
          self.output_file:write(chunk)
        end
      end,
      on_result = function(self)
        self.output_file:flush()
      end,
      on_dispose = function(self)
        self.output_file:close()
      end,
    }
  end,
}
