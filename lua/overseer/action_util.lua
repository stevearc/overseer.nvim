local config = require("overseer.config")
local log = require("overseer.log")
local task_list = require("overseer.task_list")
local util = require("overseer.util")

local M = {}

M.run_task_action = function(task, name)
  M.run_action({
    actions = config.actions,
    name = name,
    prompt = string.format("Actions: %s", task.name),
    pre_action = function()
      task:inc_reference()
    end,
    post_action = function()
      task:dec_reference()
      task_list.update(task)
    end,
  }, task)
end

M.run_action = function(opts, ...)
  vim.validate({
    actions = { opts.actions, "t" },
    name = { opts.name, "s", true },
    prompt = { opts.prompt, "s" },
    pre_action = { opts.post_action, "f", true },
    post_action = { opts.post_action, "f", true },
  })
  local args = util.pack(...)
  local viable = {}
  local longest_name = 1
  for k, action in pairs(opts.actions) do
    if action.condition == nil or action.condition(...) then
      if k == opts.name then
        if opts.pre_action then
          opts.pre_action(...)
        end
        action.run(...)
        if opts.post_action then
          opts.post_action(...)
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
    log:warn("Cannot perform action '%s'", opts.name)
    return
  end
  table.sort(viable, function(a, b)
    return a.name < b.name
  end)

  if opts.pre_action then
    opts.pre_action(...)
  end
  vim.ui.select(viable, {
    prompt = opts.prompt,
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
      if action.condition == nil or action.condition(unpack(args)) then
        action.run(unpack(args))
      else
        log:warn("Can no longer perform action '%s' on task", action.name)
      end
      if opts.post_action then
        opts.post_action(unpack(args))
      end
    end
  end)
end

return M
