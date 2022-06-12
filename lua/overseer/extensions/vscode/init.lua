local constants = require("overseer.constants")
local files = require("overseer.files")
local template = require("overseer.template")
local variables = require("overseer.extensions.vscode.variables")
local STATUS = constants.STATUS

local M = {}

local function get_npm_bin(name)
  local package_bin = files.join("node_modules", ".bin", name)
  if files.exists(package_bin) then
    return package_bin
  end
  return name
end

M.get_cmd = function(defn)
  -- TODO support more task types: gulp, grunt, jake
  if defn.type == "process" then
    local cmd = defn.args or {}
    table.insert(cmd, 1, defn.command)
    return cmd
  elseif defn.type == "shell" then
    local args = {}
    for _, arg in ipairs(defn.args or {}) do
      if type(arg) == "string" then
        table.insert(args, vim.fn.shellescape(arg))
      else
        -- TODO we are ignoring the quoting option for now
        table.insert(args, vim.fn.shellescape(arg.value))
      end
    end
    if #args > 0 then
      return string.format("%s %s", defn.command, table.concat(args, " "))
    else
      return defn.command
    end
  elseif defn.type == "npm" then
    local use_yarn = files.exists("yarn.lock")
    return { use_yarn and "yarn" or "npm", defn.script }
  elseif defn.type == "typescript" then
    local cmd = { get_npm_bin("tsc") }
    if defn.tsconfig then
      table.insert(cmd, "-p")
      table.insert(cmd, defn.tsconfig)
    end
    if defn.option then
      table.insert(cmd, string.format("--%s", defn.option))
    end
    return cmd
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
  clean = constants.TAG.CLEAN,
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
          -- TODO this is kind of a hack. Create a dummy task that kicks off the others.
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
  local cmd = M.get_cmd(defn)
  if not cmd then
    return nil
  end
  local opt = defn.options

  local tmpl = {
    name = defn.label,
    description = defn.detail,
    params = M.parse_params(defn),
    builder = function(self, params)
      local task = {
        name = defn.label,
        cmd = variables.replace_vars(cmd, params),
        components = {
          { "vscode.result_vscode_task", problem_matcher = defn.problemMatcher },
          "default_vscode",
        },
      }
      if defn.problemMatcher then
        table.insert(task.components, "on_result_diagnostics")
      end
      if defn.isBackground then
        table.insert(task.components, "on_result_rerun")
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
      if defn.isDefault then
        tmpl.priority = 40
      end
    end
  end

  -- NOTE: we ignore defn.presentation
  -- NOTE: we intentionally do nothing with defn.runOptions.
  -- runOptions.reevaluateOnRun unfortunately doesn't mesh with how we re-run tasks
  -- runOptions.runOn allows tasks to auto-run, which I philosophically oppose
  return template.new(tmpl)
end

M.vscode_tasks = {
  name = "vscode_tasks",
  params = {},
  condition = {
    callback = function(self, opts)
      return files.exists(files.join(opts.dir, ".vscode", "tasks.json"))
    end,
  },
  metagen = function(self, opts)
    local content = files.load_json_file(files.join(opts.dir, ".vscode", "tasks.json"), true)
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
