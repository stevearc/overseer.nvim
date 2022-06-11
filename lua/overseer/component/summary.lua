local util = require("overseer.util")
local M = {}

M.on_output_summarize = {
  name = "on_output_summarize",
  description = "Summarize stdout/stderr in the sidebar",
  params = {
    max_lines = { type = "number", default = 4 },
  },
  constructor = function(params)
    return {
      lines = { "" },
      on_reset = function(self)
        self.lines = { "" }
      end,
      on_output = function(self, task, data)
        for i, chunk in ipairs(data) do
          if chunk == "" then
            if self.lines[#self.lines] ~= "" then
              table.insert(self.lines, "")
            end
          else
            chunk = util.remove_ansi(string.gsub(chunk, "\r$", ""))
            if i == 1 then
              local last_line = self.lines[#self.lines]
              self.lines[#self.lines] = last_line .. chunk
            else
              table.insert(self.lines, chunk)
            end
          end
        end
        while #self.lines > params.max_lines + 1 do
          table.remove(self.lines, 1)
        end
      end,
      render = function(self, task, lines, highlights, detail)
        local prefix = "out: "
        if detail == 1 then
          local last_line
          for i = #self.lines, 1, -1 do
            last_line = self.lines[i]
            if last_line ~= "" then
              break
            end
          end
          if last_line ~= "" then
            table.insert(lines, prefix .. last_line)
            table.insert(highlights, { "Comment", #lines, 0, 4 })
            table.insert(highlights, { "OverseerOutput", #lines, 4, -1 })
          end
        else
          for _, line in ipairs(self.lines) do
            if line ~= "" then
              table.insert(lines, prefix .. line)
              table.insert(highlights, { "Comment", #lines, 0, 4 })
              table.insert(highlights, { "OverseerOutput", #lines, 4, -1 })
            end
          end
        end
      end,
    }
  end,
}

M.on_output_write_file = {
  name = "on_output_write_file",
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

return M
