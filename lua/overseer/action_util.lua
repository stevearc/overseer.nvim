local actions = require("overseer.task_list.actions")
local config = require("overseer.config")
local task_list = require("overseer.task_list")
local util = require("overseer.util")

local M = {}

---@param opts {name?: string, pre_action: fun(task: overseer.Task), post_action: fun(task: overseer.Task)}
---@param task overseer.Task
local function run_action(opts, task)
  vim.validate("name", opts.name, "string", true)
  vim.validate("pre_action", opts.post_action, "function", true)
  vim.validate("post_action", opts.post_action, "function", true)

  -- First merge the config actions with the builtins
  local all_actions = {}
  for k, v in pairs(actions) do
    all_actions[k] = v
  end
  for k, v in pairs(config.actions) do
    if v then
      all_actions[k] = v
    else
      -- If the user set the action to false, remove it from the list
      all_actions[k] = nil
    end
  end

  local viable = {}
  local longest_name = 1
  for k, action in pairs(all_actions) do
    if action.condition == nil or action.condition(task) then
      if k == opts.name then
        if opts.pre_action then
          opts.pre_action(task)
        end
        action.run(task)
        if opts.post_action then
          opts.post_action(task)
        end
        return
      end

      action.name = k
      local name_len = vim.api.nvim_strwidth(k)
      if name_len > longest_name then
        longest_name = name_len
      end
      table.insert(viable, action)
    end
  end
  if opts.name then
    vim.notify(string.format("Cannot perform action '%s'", opts.name), vim.log.levels.ERROR)
    return
  end
  table.sort(viable, function(a, b)
    return a.name < b.name
  end)

  if opts.pre_action then
    opts.pre_action(task)
  end
  vim.ui.select(viable, {
    prompt = string.format("Actions: %s", task.name),
    kind = "overseer_task_options",
    format_item = function(action)
      if action.desc then
        return string.format("%s (%s)", util.ljust(action.name, longest_name), action.desc)
      else
        return action.name
      end
    end,
  }, function(action)
    if action then
      if action.condition == nil or action.condition(task) then
        action.run(task)
      else
        vim.notify(
          string.format("Can no longer perform action '%s' on task", action.name),
          vim.log.levels.ERROR
        )
      end
    end
    if opts.post_action then
      opts.post_action(task)
    end
  end)
end

---@param task overseer.Task
---@param name? string
M.run_task_action = function(task, name)
  run_action({
    name = name,
    pre_action = function()
      task:inc_reference()
    end,
    post_action = function()
      task:dec_reference()
      task_list.touch(task)
    end,
  }, task)
end

return M
