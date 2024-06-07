local constants = require("overseer.constants")
local files = require("overseer.files")
local log = require("overseer.log")
local problem_matcher = require("overseer.template.vscode.problem_matcher")
local variables = require("overseer.template.vscode.variables")
local vs_util = require("overseer.template.vscode.vs_util")

local LAUNCH_CONFIG_KEY = "__launch_config__ "

---@param params table
---@param str string
---@param inputs table
local function extract_params(params, str, inputs)
  if not str then
    return
  end
  for name in string.gmatch(str, "%${input:([%w_]+)}") do
    local schema = inputs[name]
    if schema then
      if schema.type == "pickString" then
        local choices = {}
        local paramType = nil
        for _, v in ipairs(schema.options) do
          local choiceType
          if type(v) == "table" then
            choiceType = "namedEnum"
            -- NOTE: There is an assumption that labels are unique
            -- VSCode does not seem to require that, but it's too much of a hassle to deal with it
            choices[v.label] = v.value
          else
            choiceType = "enum"
            table.insert(choices, v)
          end

          if paramType == nil or choiceType == paramType then
            paramType = choiceType
          else
            log.error("VS Code task input %s mixes labeled and unlabeled options", name)
            break
          end
        end

        params[name] = {
          desc = schema.desc,
          default = schema.default,
          type = paramType,
          choices = choices,
        }
      elseif schema.type == "promptString" then
        params[name] = { desc = schema.desc, default = schema.default }
      elseif schema.type == "command" then
        -- TODO command inputs not supported yet
      end
    end
  end
end

local function parse_params(defn)
  if not defn.inputs then
    return {}
  end
  local input_lookup = {}
  for _, input in ipairs(defn.inputs) do
    input_lookup[input.id] = input
  end
  local params = {}
  -- TODO I think we need to parse more than the 'command', in the case of custom tasks
  extract_params(params, defn.command, input_lookup)
  if defn.args then
    for _, arg in ipairs(defn.args) do
      if type(arg) == "string" then
        extract_params(params, arg, input_lookup)
      else
        extract_params(params, arg.value, input_lookup)
      end
    end
  end

  local opt = defn.options
  if opt then
    extract_params(params, opt.cwd, input_lookup)
    if opt.env then
      for _, v in pairs(opt.env) do
        extract_params(params, v, input_lookup)
      end
    end
  end
  -- TODO opt.shell not supported yet

  return params
end

local group_to_tag = {
  build = constants.TAG.BUILD,
  run = constants.TAG.RUN,
  test = constants.TAG.TEST,
  clean = constants.TAG.CLEAN,
}

local function register_provider(task_provider)
  if task_provider.problem_patterns then
    for k, v in pairs(task_provider.problem_patterns) do
      problem_matcher.register_pattern(k, v)
    end
  end
  if task_provider.problem_matchers then
    for k, v in pairs(task_provider.problem_matchers) do
      problem_matcher.register_problem_matcher(k, v)
    end
  end
  if task_provider.on_load then
    task_provider.on_load()
  end
end

local registered_providers = {}
local function get_provider(type)
  local ok, task_provider =
    pcall(require, string.format("overseer.template.vscode.provider.%s", type))
  if ok then
    if not registered_providers[type] then
      register_provider(task_provider)
      registered_providers[type] = true
    end
    return task_provider
  else
    return nil
  end
end

---See https://code.visualstudio.com/docs/editor/tasks#_output-behavior
---@param defn table
---@return table[]
local function get_presentation_components(defn)
  local ret = {}
  local presentation = defn.presentation
  if not presentation then
    return ret
  end

  -- VSCode defaults to "always", but Neovim has a different design philosophy (don't clutter the UI
  -- with every little thing), so we are changing the default to "never".
  local reveal = presentation.reveal or "never"
  if reveal == "always" then
    table.insert(ret, { "open_output", focus = defn.focus })
  elseif reveal == "silent" then
    table.insert(ret, {
      "open_output",
      focus = defn.focus,
      on_start = "never",
      on_complete = "failure",
      on_result = "if_diagnostics",
    })
  end

  local reveal_problems = presentation.revealProblems or "never"
  -- Another departure from VSCode behavior: treat revealProblems="always" the same as "onProblem".
  if reveal_problems == "always" or reveal_problems == "onProblem" then
    local has_trouble = pcall(require, "trouble")
    if has_trouble then
      table.insert(ret, { "on_result_diagnostics_trouble" })
    else
      table.insert(ret, { "on_result_diagnostics_quickfix", open = true })
    end
  elseif defn.problemMatcher then
    -- If there's no revealProblems but there is a problemMatcher, set the results in the quickfix
    -- anyway (just don't auto open it)
    table.insert(ret, "on_result_diagnostics_quickfix")
  end

  -- NOTE: we are not yet making use of:
  -- - echo
  -- - showReuseMessage
  -- - panel
  -- - clear
  -- - close
  -- - group
  return ret
end

---@param defn table
---@param precalculated_vars table
local function get_task_builder(defn, precalculated_vars)
  local task_provider = get_provider(defn.type)
  if not task_provider then
    return nil
  end
  return function(params)
    defn = vim.deepcopy(defn)
    defn.command = variables.replace_vars(defn.command, params, precalculated_vars)
    defn.args = variables.replace_vars(defn.args, params, precalculated_vars)
    if defn.options then
      defn.options.cwd = variables.replace_vars(defn.options.cwd, params, precalculated_vars)
      defn.options.env = variables.replace_vars(defn.options.env, params, precalculated_vars)
    end
    -- Pass the provider the raw task definition data and the launch.json configuration data
    -- (if present)
    local task_opts = task_provider.get_task_opts(defn, params[LAUNCH_CONFIG_KEY])
    local opts = vim.tbl_deep_extend("force", defn.options or {}, task_opts)
    local components = { "default_vscode" }
    local pmatcher = defn.problemMatcher
    if not pmatcher and task_provider.problem_matcher then
      pmatcher = task_provider.problem_matcher
    end
    if pmatcher then
      table.insert(components, 1, {
        "on_output_parse",
        problem_matcher = pmatcher,
      })
    end
    if defn.isBackground then
      table.insert(components, "on_complete_restart")
    end
    vim.list_extend(components, get_presentation_components(defn))

    local task = {
      name = defn.label,
      cmd = opts.cmd,
      cwd = opts.cwd,
      env = opts.env,
      components = components,
    }
    return task
  end
end

---@param defn table
---@param precalculated_vars table
local function convert_vscode_task(defn, precalculated_vars)
  local alias = string.format("%s: %s", defn.type, defn.command)
  local tmpl = {
    name = defn.label or alias,
    -- VS Code seems to be able to specify tasks as type: label (e.g. "npm: build")
    aliases = { alias },
    desc = defn.detail,
    params = parse_params(defn),
  }

  local task_builder = get_task_builder(defn, precalculated_vars)
  -- If we don't have a task builder, but the type exists, then we don't support this task type
  if not task_builder and defn.type then
    log:warn("Unsupported VSCode task type '%s' for task %s", defn.type, tmpl.name)
    return nil
  end

  if defn.group then
    if type(defn.group) == "string" then
      tmpl.tags = { group_to_tag[defn.group] }
    else
      tmpl.tags = { group_to_tag[defn.group.kind] }
      if defn.isDefault then
        tmpl.priority = 40
      end
    end
  end
  if defn.dependsOn then
    if type(defn.dependsOn) == "string" then
      defn.dependsOn = { defn.dependsOn }
    end

    if task_builder then
      tmpl.builder = function(params)
        local task_defn = task_builder(params)
        table.insert(task_defn.components, {
          "dependencies",
          task_names = defn.dependsOn,
          sequential = defn.dependsOrder == "sequence",
        })
        return task_defn
      end
      return tmpl
    else
      -- This is a meta-task (just an aggregation of other, dependency tasks).
      -- Create a task with the orechestrator strategy
      tmpl.params = {}
      local dep_tasks = defn.dependsOn
      if defn.dependsOrder ~= "sequence" then
        dep_tasks = { dep_tasks }
      end
      tmpl.builder = function(params)
        dep_tasks = vim.deepcopy(dep_tasks)
        return {
          name = defn.label,
          strategy = { "orchestrator", tasks = dep_tasks },
          components = {
            "on_complete_dispose",
          },
        }
      end
    end
  elseif task_builder then
    tmpl.builder = task_builder
  else
    log:warn(
      'VSCode task \'%s\' is missing type. Try setting "type": "shell"',
      defn.label or defn.name or defn.command
    )
    return nil
  end
  if defn.hide then
    tmpl.hide = true
  end

  -- NOTE: we intentionally do nothing with defn.runOptions.
  -- runOptions.reevaluateOnRun unfortunately doesn't mesh with how we re-run tasks
  -- runOptions.runOn allows tasks to auto-run, which I philosophically oppose
  return tmpl
end

return {
  cache_key = function(opts)
    return vs_util.get_tasks_file(vim.fn.getcwd(), opts.dir)
  end,
  condition = {
    callback = function(opts)
      if not vs_util.get_tasks_file(vim.fn.getcwd(), opts.dir) then
        return false, "No .vscode/tasks.json file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local tasks_file = vs_util.get_tasks_file(vim.fn.getcwd(), opts.dir)
    local content = vs_util.load_tasks_file(assert(tasks_file))
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
    local precalculated_vars = variables.precalculate_vars()
    for _, task in ipairs(content.tasks) do
      local defn = vim.tbl_deep_extend("force", global_defaults, task)
      defn = vim.tbl_deep_extend("force", defn, task[os_key] or {})
      local tmpl = convert_vscode_task(defn, precalculated_vars)
      if tmpl then
        table.insert(ret, tmpl)
      end
    end
    cb(ret)
  end,
  -- expose these for unit tests
  get_provider = get_provider,
  convert_vscode_task = convert_vscode_task,
  LAUNCH_CONFIG_KEY = LAUNCH_CONFIG_KEY,
}
