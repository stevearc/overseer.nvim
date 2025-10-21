local M = {}

local conf = {}

M.config = function(data)
  conf = data
end

M.on_save = function()
  local config = require("overseer.config")
  local task_list = require("overseer.task_list")
  local opts = vim.tbl_deep_extend("keep", conf or {}, config.bundles.save_task_opts)
  local serialized = vim.tbl_map(function(task)
    return task:serialize()
  end, task_list.list_tasks(opts))
  if #serialized > 0 then
    return serialized
  end
end

M.on_load = function(data)
  local overseer = require("overseer")
  local config = require("overseer.config")
  local task_list = require("overseer.task_list")
  while true do
    local task = task_list.get_by_index(1)
    if task == nil then
      break
    end
    task:dispose(true)
  end
  for _, params in ipairs(data) do
    local task = overseer.new_task(params)
    if config.bundles.autostart_on_load then
      task:start()
    end
  end
end

M.is_win_supported = function(winid, bufnr)
  return vim.bo[bufnr].filetype == "OverseerList"
end

M.save_win = function(winid)
  local sidebar = require("overseer.task_list.sidebar")
  local sb = sidebar.get()
  return {
    default_detail = sb.default_detail,
  }
end

M.load_win = function(winid, data)
  local sidebar = require("overseer.task_list.sidebar")
  local window = require("overseer.window")
  window.open({ winid = winid })
  local sb = sidebar.get_or_create()
  if data.default_detail then
    sb:change_default_detail(data.default_detail - sb.default_detail)
  end
end

return M
