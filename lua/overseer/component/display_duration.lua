local task_list = require("overseer.task_list")
local util = require("overseer.util")

local timer

---@type overseer.ComponentFileDefinition
local comp = {
  desc = "Display the run duration",
  params = {
    detail_level = {
      desc = "Show the duration at this detail level",
      type = "integer",
      default = 1,
      validate = function(v)
        return v >= 1 and v <= 3
      end,
    },
  },
  constructor = function(params)
    return {
      duration = nil,
      start_time = nil,
      on_reset = function(self, task)
        self.duration = nil
        self.start_time = nil
      end,
      on_start = function(self)
        if not timer then
          timer = assert(vim.uv.new_timer())
          timer:start(
            1000,
            1000,
            vim.schedule_wrap(function()
              task_list.rerender()
            end)
          )
        end
        self.start_time = os.time()
      end,
      on_complete = function(self)
        self.duration = os.time() - self.start_time
      end,
      render = function(self, task, lines, highlights, detail)
        if detail < params.detail_level or (not self.duration and not self.start_time) then
          return
        end
        local duration = self.duration or os.time() - self.start_time
        table.insert(lines, util.format_duration(duration))
      end,
    }
  end,
}

return comp
