local util = require("overseer.util")

return {
  description = "Summarize stdout/stderr in the sidebar",
  params = {
    max_lines = {
      type = "int",
      default = 4,
      validate = function(v)
        return v > 0
      end,
    },
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
