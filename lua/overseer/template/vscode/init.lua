local constants = require("overseer.constants")
local files = require("overseer.files")
local log = require("overseer.log")
local variables = require("overseer.template.vscode.variables")
local STATUS = constants.STATUS

local function extract_params(params, str, inputs)
  if not str then
    return
  end
  for name in string.gmatch(str, "%${input:(%a+)}") do
    local schema = inputs[name]
    if schema then
      if schema.type == "pickString" then
        local choices = {}
        for _, v in ipairs(schema.options) do
          if type(v) == "table" then
            table.insert(choices, v.value)
          else
            table.insert(choices, v)
          end
        end
        params[name] = {
          desc = schema.desc,
          default = schema.default,
          type = "enum",
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
  extract_params(params, defn.command, input_lookup)
  if defn.args then
    for _, arg in ipairs(defn.args) do
      extract_params(params, arg, input_lookup)
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
  test = constants.TAG.TEST,
  build = constants.TAG.BUILD,
  clean = constants.TAG.CLEAN,
}

local BaseTaskProvider = {
  get_cmd = function(defn)
    error("Task provider must provide 'get_cmd' function")
  end,
  validate = function(defn)
    return true
  end,
}

local function get_provider(type)
  local ok, task_provider = pcall(
    require,
    string.format("overseer.template.vscode.provider.%s", type)
  )
  if ok then
    return setmetatable(task_provider, { __index = BaseTaskProvider })
  else
    log:warn("No VS Code task provider for '%s'", type)
    return nil
  end
end

local function convert_vscode_task(defn)
  local task_provider = get_provider(defn.type)
  if not task_provider or not task_provider.validate(defn) then
    return
  end

  local sequence = defn.dependsOrder == "sequence"
  if type(defn.dependsOn) == "string" then
    defn.dependsOn = { defn.dependsOn }
  end
  local tmpl = {
    name = defn.label,
    desc = defn.detail,
    params = parse_params(defn),
    builder = function(params)
      local cmd = task_provider.get_cmd(defn)
      local task = {
        name = defn.label,
        cmd = variables.replace_vars(cmd, params),
        components = {
          { "vscode.result_vscode_task", problem_matcher = defn.problemMatcher },
          "default_vscode",
        },
      }
      -- FIXME use an orchestrator once we have one
      if defn.dependsOn then
        table.insert(task.components, {
          "on_status_run_task",
          status = sequence and STATUS.SUCCESS or STATUS.RUNNING,
          task_names = defn.dependsOn,
          once = true,
          sequence = sequence,
        })
      end
      if defn.problemMatcher then
        table.insert(task.components, "on_result_diagnostics")
      end
      if defn.isBackground then
        table.insert(task.components, "on_result_restart")
      end
      local opt = defn.options
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
      if defn.isDefault then
        tmpl.priority = 40
      end
    end
  end

  -- NOTE: we ignore defn.presentation
  -- NOTE: we intentionally do nothing with defn.runOptions.
  -- runOptions.reevaluateOnRun unfortunately doesn't mesh with how we re-run tasks
  -- runOptions.runOn allows tasks to auto-run, which I philosophically oppose
  return tmpl
end

return {
  condition = {
    callback = function(opts)
      return files.exists(files.join(opts.dir, ".vscode", "tasks.json"))
    end,
  },
  generator = function(opts)
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
      local tmpl = convert_vscode_task(defn)
      if tmpl then
        table.insert(ret, tmpl)
      end
    end
    return ret
  end,
  -- expose these for unit tests
  get_provider = get_provider,
  convert_vscode_task = convert_vscode_task,
}
