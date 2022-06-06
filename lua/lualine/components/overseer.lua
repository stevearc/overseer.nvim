-- ## Usage
--
--   require("lualine").setup({
--     sections = {
--       lualine_x = { "overseer" },
--     },
--   })
--
--   Or with options:
--   require("lualine").setup({
--     sections = {
--       lualine_x = { {"overseer", label = 'T:', colored = false} },
--     },
--   })
--
-- ## Options
--
-- *colored* (default: true)
--   Color the task icons.
--
-- *symbols*
--   Mapping of task status to symbol representation
--
-- *label* (default: 'Tasks:')
--   Prefix to put in front of task counts.
--
-- *unique* (default: false)
--   If true, ignore tasks with duplicate names.
--
-- *name* (default: nil)
--   String or list of strings. Only count tasks with this name or names.
--
-- *name_not* (default: false)
--   When true, count all tasks that do *not* match the 'name' param.
--
-- *status* (default: nil)
--   String or list of strings. Only count tasks with this status.
--
-- *status_not* (default: false)
--   When true, count all tasks that do *not* match the 'status' param.

local M = require("lualine.component"):extend()
local constants = require("overseer.constants")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local utils = require("lualine.utils.utils")
local STATUS = constants.STATUS

local default_icons = {
  [STATUS.FAILURE] = " ",
  [STATUS.CANCELED] = " ",
  [STATUS.SUCCESS] = " ",
  [STATUS.RUNNING] = "省",
}
local default_no_icons = {
  [STATUS.FAILURE] = "F:",
  [STATUS.CANCELED] = "C:",
  [STATUS.SUCCESS] = "S:",
  [STATUS.RUNNING] = "R:",
}

function M:init(options)
  options.recent_first = true
  M.super.init(self, options)

  self.options.label = self.options.label or "Tasks:"
  if self.options.colored == nil then
    self.options.colored = true
  end
  if self.options.colored then
    self.highlight_groups = {}
    for _, status in ipairs(STATUS.values) do
      local hl = string.format("Overseer%s", status)
      local color = { fg = utils.extract_color_from_hllist("fg", { hl }) }
      self.highlight_groups[status] = self:create_hl(color, status)
    end
  end
  self.symbols = vim.tbl_extend(
    "keep",
    self.options.symbols or {},
    self.options.icons_enabled ~= false and default_icons or default_no_icons
  )
end

function M:update_status()
  local tasks = task_list.list_tasks(self.options)
  local tasks_by_status = util.tbl_group_by(tasks, "status")
  local pieces = {}
  if self.options.label ~= "" then
    table.insert(pieces, self.options.label)
  end
  for _, status in ipairs(STATUS.values) do
    local status_tasks = tasks_by_status[status]
    if self.symbols[status] and status_tasks then
      if self.options.colored then
        local hl_start = self:format_hl(self.highlight_groups[status])
        table.insert(pieces, string.format("%s%s%s", hl_start, self.symbols[status], #status_tasks))
      else
        table.insert(pieces, string.format("%s %s", self.symbols[status], #status_tasks))
      end
    end
  end
  if #pieces > 0 then
    return table.concat(pieces, " ")
  end
end

return M
