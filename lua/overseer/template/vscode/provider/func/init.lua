-- Task provider for Azure functions.
-- VS Code task definition provided by https://github.com/microsoft/vscode-azurefunctions
-- Reference implementation: https://github.com/microsoft/vscode-azurefunctions/blob/411ece5f9453af075c1ff48c70aec349f5942a47/src/debug/FuncTaskProvider.ts#L101
local log = require("overseer.log")
local vs_util = require("overseer.template.vscode.vs_util")
local M = {}

M.problem_patterns = {
  ["$func"] = {
    kind = "file",
    regexp = "^.*Missing.*AzureWebJobsStorage.*(local.settings.json).*$",
    file = 1,
    message = 0,
  },
}

M.problem_matchers = {
  ["$func-watch"] = {
    label = "%azureFunctions.problemMatchers.funcWatch%",
    owner = "Azure Functions",
    source = "func",
    applyTo = "allDocuments",
    fileLocation = { "relative", "${workspaceFolder}" },
    pattern = "$func",
    background = {
      activeOnStart = true,
      beginsPattern = "^.*(Job host stopped|signaling restart).*$",
      endsPattern = "^.*(Worker process started and initialized|Host lock lease acquired by instance ID).*$",
    },
    severity = "error",
  },
  ["$func-dotnet-watch"] = {
    label = "%azureFunctions.problemMatchers.funcDotnetWatch%",
    base = "$func-watch",
  },
  ["$func-java-watch"] = {
    label = "%azureFunctions.problemMatchers.funcJavaWatch%",
    base = "$func-watch",
  },
  ["$func-node-watch"] = {
    label = "%azureFunctions.problemMatchers.funcNodeWatch%",
    base = "$func-watch",
  },
  ["$func-powershell-watch"] = {
    label = "%azureFunctions.problemMatchers.funcPowerShellWatch%",
    base = "$func-watch",
    background = {
      activeOnStart = true,
      beginsPattern = "^.*(Job host stopped|signaling restart).*$",
      endsPattern = "^.*(Host lock lease acquired by instance ID).*$",
    },
  },
  ["$func-python-watch"] = {
    label = "%azureFunctions.problemMatchers.funcPythonWatch%",
    base = "$func-watch",
  },
}

---@param language? string
---@return string|nil
local function get_runtime_from_language(language)
  if language == "python" then
    return "python"
  elseif language == "javascript" or language == "typescript" then
    return "node"
  elseif language == "java" then
    return "java"
  elseif language == "powershell" then
    return "powershell"
  elseif language == "fsharp" or language == "csharp" or language == "cs" then
    return "dotnet"
  end
end

---@param runtime? string
---@return table|nil
local function get_debug_provider(runtime)
  local ok, debug =
    pcall(require, string.format("overseer.template.vscode.provider.func.debug_%s", runtime))
  if ok then
    return debug
  else
    return nil
  end
end

---@param runtime string
---@param launch_config nil|table
local function get_host_start_options(runtime, launch_config)
  local debug_provider = get_debug_provider(runtime)
  if debug_provider then
    if os.getenv(debug_provider.worker_arg_key) then
      -- If the env var is already set, don't override it
      return nil
    else
      return {
        env = {
          [debug_provider.worker_arg_key] = debug_provider.get_worker_arg_value(launch_config),
        },
      }
    end
  else
    log:warn("Azure func task provider could not find debug provider for runtime %s", runtime)
    return nil
  end
end

M.get_task_opts = function(defn, launch_config)
  local cmd = string.format("func %s", defn.command)
  local ret = {
    cmd = cmd,
  }

  if defn.command:match("^%s*host start") or defn.command:match("^%s*start") then
    local language = vs_util.get_workspace_language()
    local runtime = get_runtime_from_language(language)
    if not defn.problemMatcher then
      if runtime then
        ret.problem_matcher = string.format("$func-%s-watch", runtime)
      else
        log:warn("Azure func task provider could not find runtime for language %s", language)
        ret.problem_matcher = "$func-watch"
      end
    end
    if runtime then
      local start_opts = get_host_start_options(runtime, launch_config)
      ret = vim.tbl_deep_extend("force", ret, start_opts or {})
    else
      log:warn("Azure func task provider could not find debug provider for language %s", language)
    end
  end

  return ret
end

return M
