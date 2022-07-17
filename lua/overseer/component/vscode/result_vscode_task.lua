local constants = require("overseer.constants")
local parser = require("overseer.parser")
local problem_matcher = require("overseer.template.vscode.problem_matcher")
local STATUS = constants.STATUS

local function pattern_to_test(pattern)
  if not pattern then
    return nil
  elseif type(pattern) == "string" then
    local pat = "\\v" .. pattern
    return function(line)
      return vim.fn.match(line, pat) ~= -1
    end
  else
    return pattern_to_test(pattern.regexp)
  end
end

return {
  desc = "Parses VS Code task output",
  params = {
    problem_matcher = { type = "opaque", optional = true },
  },
  constructor = function(params)
    local pm = problem_matcher.resolve_problem_matcher(params.problem_matcher)
    local parser_defn = problem_matcher.get_parser_from_problem_matcher(pm)
    local p
    local begin_test
    local end_test
    local active_on_start = true
    if parser_defn then
      p = parser.new({ diagnostics = parser_defn })
      local background = pm.background
      if vim.tbl_islist(pm) then
        for _, v in ipairs(pm) do
          if v.background then
            background = v.background
            break
          end
        end
      end
      if background then
        active_on_start = background.activeOnStart
        begin_test = pattern_to_test(background.beginsPattern)
        end_test = pattern_to_test(background.endsPattern)
      end
    end
    return {
      parser = p,
      active = active_on_start,
      on_reset = function(self, task, soft)
        if not soft then
          self.active = active_on_start
        end
        if self.parser then
          self.parser:reset()
        end
      end,
      on_output_lines = function(self, task, lines)
        if self.parser then
          for _, line in ipairs(lines) do
            if self.active then
              if end_test and end_test(line) then
                task:set_result(self.parser:get_result())
                self.active = false
              end
            elseif begin_test and begin_test(line) then
              self.active = true
              task:reset(true)
            end
            if self.active then
              self.parser:ingest({ line })
            end
          end
        end
      end,
      on_pre_result = function(self, task)
        if self.parser then
          return self.parser:get_result()
        end
      end,
      on_exit = function(self, task, code)
        local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
        task:finalize(status)
      end,
    }
  end,
}
