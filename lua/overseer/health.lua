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

  for name, tmpl_report in pairs(info.templates.templates) do
    if tmpl_report.is_present then
      vim.health.ok(string.format("%s: available", name))
    else
      vim.health.warn(string.format("%s: %s", name, tmpl_report.message))
    end
  end
  for name, provider_report in pairs(info.templates.providers) do
    if provider_report.is_present then
      if provider_report.from_cache then
        name = name .. " (cached)"
      end
      vim.health.ok(
        string.format(
          "%s: %d/%d tasks available",
          name,
          provider_report.available_tasks,
          provider_report.total_tasks
        )
      )
    else
      vim.health.warn(string.format("%s: %s", name, provider_report.message))
    end
  end
end

return M
