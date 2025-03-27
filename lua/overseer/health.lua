local commands = require("overseer.commands")
local config = require("overseer.config")
local log = require("overseer.log")
local overseer = require("overseer")

local M = {}

local level_map = {}
for k, v in pairs(vim.log.levels) do
  level_map[v] = k
end

M.check = function()
  vim.health.start("overseer.nvim report")

  if vim.fn.has("nvim-0.10") == 0 then
    vim.health.error("Neovim 0.10 or later is required")
  end
  if not overseer.called_setup then
    vim.health.error('require("overseer").setup() was not called')
  end
  vim.health.info(string.format("Log file: %s", log.get_logfile()))
  vim.health.info(string.format("Log level: %s", level_map[config.log_level]))

  ---@type overseer.Report
  local info
  commands.info(function(info_cb)
    info = info_cb
  end)

  vim.wait(10000, function()
    return info ~= nil
  end)

  if not info then
    vim.health.warn("timeout waiting for tasks to generate")
    return
  end

  for name, tmpl_report in pairs(info.templates) do
    if tmpl_report.message then
      vim.health.warn(string.format("%s: %s", name, tmpl_report.message))
    else
      vim.health.ok(string.format("%s: available", name))
    end
  end
  local provider_names = vim.tbl_keys(info.providers)
  table.sort(provider_names, function(a_name, b_name)
    local a, b = info.providers[a_name], info.providers[b_name]
    local a_err, b_err = a.message ~= nil, b.message ~= nil
    if a_err ~= b_err then
      return not a_err
    end
    return a_name < b_name
  end)
  for _, name in ipairs(provider_names) do
    local provider_report = info.providers[name]
    if name:match("^[%w_%.%-]+$") then
      name = "{" .. name .. "}"
    end
    if provider_report.message then
      vim.health.warn(string.format("%s: %s", name, provider_report.message))
    else
      if provider_report.from_cache then
        name = name .. " (cached)"
      elseif provider_report.elapsed_ms > 0 then
        name = string.format("%s (%sms)", name, provider_report.elapsed_ms)
      end
      vim.health.ok(
        string.format(
          "%s: `%d/%d tasks available`",
          name,
          provider_report.available_tasks,
          provider_report.total_tasks
        )
      )
    end
  end
end

return M
