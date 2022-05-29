local constants = require("overseer.constants")
local files = require("overseer.files")
local parser = require("overseer.parser")
local problem_matcher = require("overseer.extensions.vscode.problem_matcher")
local template = require("overseer.template")
local variables = require("overseer.extensions.vscode.variables")
local STATUS = constants.STATUS

local M = {}

M.get_cmd = function(defn)
  if defn.type == "process" then
    local cmd = defn.args or {}
    table.insert(cmd, 1, defn.command)
    return cmd
  else
    local args = {}
    for _, arg in ipairs(defn.args or {}) do
      if type(arg) == "string" then
        table.insert(args, vim.fn.shellescape(arg))
      else
        -- TODO we are ignoring the quoting option for now
        table.insert(args, vim.fn.shellescape(arg.value))
      end
    end
    local cmd = defn.command
    if cmd:match("%s") then
      cmd = vim.fn.shellescape(cmd)
    end
    if #args > 0 then
      return string.format("%s %s", defn.command, table.concat(args, " "))
    else
      return cmd
    end
  end
end

local function parse_params(params, str, inputs)
  if not str then
    return
  end
  for name in string.gmatch(str, "%${input:(%a+)}") do
    local schema = inputs[name]
    if schema then
      if schema.type == "pickString" then
        -- TODO encode the options as an enum
        params[name] = { description = schema.description, default = schema.default }
      elseif schema.type == "promptString" then
        params[name] = { description = schema.description, default = schema.default }
      elseif schema.type == "command" then
        -- TODO command inputs not supported yet
      end
    end
  end
end

M.parse_params = function(defn)
  if not defn.inputs then
    return {}
  end
  local input_lookup = {}
  for _, input in ipairs(defn.inputs) do
    input_lookup[input.id] = input
  end
  local params = {}
  parse_params(params, defn.command, input_lookup)
  if defn.args then
    for _, arg in ipairs(defn.args) do
      parse_params(params, arg, input_lookup)
    end
  end

  local opt = defn.options
  if opt then
    parse_params(params, opt.cwd, input_lookup)
    if opt.env then
      for _, v in pairs(opt.env) do
        parse_params(params, v, input_lookup)
      end
    end
  end
  -- TODO opt.shell not supported yet

  return params
end

local group_to_tag = {
  test = constants.TAG.TEST,
  build = constants.TAG.BUILD,
}

M.convert_vscode_task = function(defn)
  if defn.dependsOn then
    local sequence = defn.dependsOrder == "sequence"
    return template.new({
      name = defn.label,
      params = {},
      builder = function(self, params)
        return {
          name = defn.label,
          -- TODO this is kind of a hack
          cmd = "sleep 1",
          components = {
            "result_exit_code",
            { "dispose_delay", timeout = 1 },
            {
              "on_status_run_task",
              status = sequence and STATUS.SUCCESS or STATUS.RUNNING,
              task_names = defn.dependsOn,
              once = true,
              sequence = sequence,
            },
          },
        }
      end,
    })
  end
  -- TODO we only support shell & process tasks
  if defn.type ~= "shell" and defn.type ~= "process" then
    return nil
  end
  local cmd = M.get_cmd(defn)
  local opt = defn.options

  local tmpl = {
    name = defn.label,
    params = M.parse_params(defn),
    builder = function(self, params)
      local task = {
        name = defn.label,
        cmd = variables.replace_vars(cmd, params),
        components = {
          { "result_vscode_task", problem_matcher = defn.problemMatcher },
          "default",
        },
      }
      if defn.problemMatcher then
        table.insert(task.components, "on_result_diagnostics")
      end
      if defn.isBackground then
        table.insert(task.components, "rerun_on_result")
      end
      if opt then
        if opt.cwd then
          task.cwd = variables.replace_vars(opt.cwd, params)
        end
        if opt.env then
          local env = {}
          for k, v in pairs(opt.env) do
            env[k] = variables.replace_vars(v, params)
          end
          task.env = env
        end
      end

      return task
    end,
  }

  if defn.group then
    if type(defn.group) == "string" then
      tmpl.tags = { group_to_tag[defn.group] }
    else
      tmpl.tags = { group_to_tag[defn.group.kind] }
      -- TODO handle isDefault
    end
  end

  -- NOTE: we ignore defn.presentation
  -- NOTE: we intentionally do nothing with defn.runOptions.
  -- runOptions.reevaluateOnRun unfortunately doesn't mesh with how we re-run tasks
  -- runOptions.runOn allows tasks to auto-run, which I philosophically oppose
  return template.new(tmpl)
end

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

M.result_vscode_task = {
  name = "result_vscode_task",
  description = "Parses VS Code task output",
  params = {
    problem_matcher = { type = "opaque", optional = true },
  },
  constructor = function(params)
    local parser_defn = problem_matcher.get_parser_from_problem_matcher(params.problem_matcher)
    local p
    local begin_test
    local end_test
    local active_on_start = true
    if parser_defn then
      p = parser.new({ diagnostics = parser_defn })
      local background = params.problem_matcher and params.problem_matcher.background
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
                task:set_result(constants.STATUS.RUNNING, self.parser:get_result())
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
      on_exit = function(self, task, code)
        local status = code == 0 and STATUS.SUCCESS or STATUS.FAILURE
        if self.parser then
          task:set_result(status, self.parser:get_result())
        else
          task:set_result(status, {})
        end
      end,
    }
  end,
}

M.vscode_tasks = {
  name = "vscode_tasks",
  params = {},
  condition = {
    callback = function(self, opts)
      return files.exists(files.join(opts.dir, ".vscode", "tasks.json"))
    end,
  },
  metagen = function(self, opts)
    local content = files.load_json_file(files.join(opts.dir, ".vscode", "tasks.json"))
    local global_defaults = {}
    for k, v in pairs(content) do
      if k ~= "version" and k ~= "tasks" then
        global_defaults[k] = v
      end
    end
    local os_key
    if files.is_windows then
      os_key = "windows"
    elseif files.is_mac then
      os_key = "osx"
    else
      os_key = "linux"
    end
    if content[os_key] then
      global_defaults = vim.tbl_deep_extend("force", global_defaults, content[os_key])
    end
    local ret = {}
    for _, task in ipairs(content.tasks) do
      local defn = vim.tbl_deep_extend("force", global_defaults, task)
      defn = vim.tbl_deep_extend("force", defn, task[os_key] or {})
      local tmpl = M.convert_vscode_task(defn)
      if tmpl then
        table.insert(ret, tmpl)
      end
    end
    return ret
  end,
  builder = function() end,
}

return M
