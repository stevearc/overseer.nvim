local M = {}

---@class (exact) overseer.ResessionConfig
---@field autostart_on_load boolean Whether to start tasks when loading (default true)
---@field filter overseer.ListTaskOpts Options to use when listing tasks to save
local conf = {}

---@param data? overseer.ResessionConfig
M.config = function(data)
  conf = vim.tbl_extend("keep", data or {}, {
    autostart_on_load = true,
    filter = {
      bundleable = true,
    },
  })
end

M.on_save = function()
  local task_list = require("overseer.task_list")
  local serialized = vim.tbl_map(function(task)
    return task:serialize()
  end, task_list.list_tasks(conf.filter))
  if #serialized > 0 then
    return serialized
  end
end

M.on_load = function(data)
  local overseer = require("overseer")
  for _, params in ipairs(data) do
    local task = overseer.new_task(params)
    if conf.autostart_on_load then
      task:start()
    end
  end
end

M.is_win_supported = function(winid, bufnr)
  return vim.bo[bufnr].filetype == "OverseerList"
end

M.save_win = function(winid)
  return {}
end

M.load_win = function(winid, data)
  local sidebar = require("overseer.task_list.sidebar")
  local window = require("overseer.window")
  window.open({ winid = winid })
  sidebar.get_or_create()
end

return M
