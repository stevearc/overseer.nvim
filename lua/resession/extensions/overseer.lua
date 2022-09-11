local task_list = require("overseer.task_list")
local overseer = require("overseer")
local sidebar = require("overseer.task_list.sidebar")
local window = require("overseer.window")
local M = {}

local config = {}

M.config = function(data)
  config = vim.tbl_deep_extend("keep", config, {
    bundleable = true,
  })
end

M.on_save = function()
  return vim.tbl_map(function(task)
    return task:serialize()
  end, task_list.list_tasks(config))
end

M.on_load = function(data)
  for _, params in ipairs(data) do
    local task = overseer.new_task(params)
    task:start()
  end
end

M.is_win_supported = function(winid, bufnr)
  return vim.api.nvim_buf_get_option(bufnr, "filetype") == "OverseerList"
end

M.save_win = function(winid)
  local sb = sidebar.get()
  return {
    default_detail = sb.default_detail,
  }
end

M.load_win = function(winid, config)
  window.open({ winid = winid })
  local sb = sidebar.get_or_create()
  if config.default_detail then
    sb:change_default_detail(config.default_detail - sb.default_detail)
  end
end

return M
