local component = require("overseer.component")
local constants = require("overseer.constants")
local form = require("overseer.form")
local task_editor = require("overseer.task_editor")
local task_list = require("overseer.task_list")
local util = require("overseer.util")
local STATUS = constants.STATUS

local M

---@class (exact) overseer.Action
---@field desc? string Detailed description of what the action does
---@field condition? fun(task: overseer.Task): boolean Function to check if the action is applicable
---@field run fun(task: overseer.Task)

---@type table<string, overseer.Action>
M = {
  start = {
    condition = function(task)
      return task.status == STATUS.PENDING
    end,
    run = function(task)
      task:start()
    end,
  },
  stop = {
    condition = function(task)
      return task.status == STATUS.RUNNING
    end,
    run = function(task)
      task:stop()
    end,
  },
  restart = {
    condition = function(task)
      return task.status ~= STATUS.PENDING
    end,
    run = function(task)
      task:restart(true)
    end,
  },
  dispose = {
    run = function(task)
      task:dispose(true)
    end,
  },
  edit = {
    desc = "Edit the task components directly",
    run = function(task)
      task_editor.open(task, function(t)
        if t then
          task_list.touch(t)
        end
      end)
    end,
  },
  retain = {
    desc = "Don't automatically dispose this task after complete",
    condition = function(task)
      return task:has_component("on_complete_dispose")
    end,
    run = function(task)
      task:remove_component("on_complete_dispose")
    end,
  },
  ensure = {
    desc = "restart the task if it fails",
    condition = function(task)
      return not task:has_component("on_complete_restart")
    end,
    run = function(task)
      task:add_components({ "on_complete_restart" })
      if task.status == STATUS.FAILURE then
        task:restart()
      end
    end,
  },
  watch = {
    desc = "restart the task when you save a file",
    condition = function(task)
      return not task:has_component("restart_on_save")
    end,
    run = function(task)
      local comp = assert(component.get("restart_on_save"))
      local schema = vim.deepcopy(assert(comp.params))
      form.open("Restart task when files are written", schema, {
        paths = { vim.fn.getcwd() },
      }, function(params)
        if not params then
          return
        end
        params[1] = "restart_on_save"
        task:set_component(params)
        task_list.touch(task)
      end)
    end,
  },
  unwatch = {
    desc = "Remove the file watcher",
    condition = function(task)
      return task:has_component("restart_on_save")
    end,
    run = function(task)
      task:remove_component("restart_on_save")
    end,
  },
  ["open float"] = {
    desc = "open terminal in a floating window",
    condition = function(task)
      return task:get_bufnr() ~= nil
    end,
    run = function(task)
      task:open_output("float")
    end,
  },
  open = {
    desc = "open terminal in the current window",
    condition = function(task)
      return task:get_bufnr() ~= nil
    end,
    run = function(task)
      task:open_output()
    end,
  },
  ["open hsplit"] = {
    desc = "open terminal in a horizontal split",
    condition = function(task)
      return task:get_bufnr() ~= nil
    end,
    run = function(task)
      task:open_output("horizontal")
    end,
  },
  ["open vsplit"] = {
    desc = "open terminal in a vertical split",
    condition = function(task)
      return task:get_bufnr() ~= nil
    end,
    run = function(task)
      task:open_output("vertical")
    end,
  },
  ["open tab"] = {
    desc = "open terminal in a new tab",
    condition = function(task)
      return task:get_bufnr() ~= nil
    end,
    run = function(task)
      task:open_output("tab")
    end,
  },
  ["set quickfix diagnostics"] = {
    desc = "put the diagnostics results into quickfix",
    condition = function(task)
      return task.result ~= nil
        and task.result.diagnostics
        and not vim.tbl_isempty(task.result.diagnostics)
    end,
    run = function(task)
      vim.fn.setqflist(task.result.diagnostics)
    end,
  },
  ["set loclist diagnostics"] = {
    desc = "put the diagnostics results into loclist",
    condition = function(task)
      return task.result ~= nil
        and task.result.diagnostics
        and not vim.tbl_isempty(task.result.diagnostics)
    end,
    run = function(task)
      local winid = util.find_code_window()
      vim.fn.setloclist(winid, task.result.diagnostics)
    end,
  },
  ["open output in quickfix"] = {
    desc = "open the entire task output in quickfix",
    condition = function(task)
      local bufnr = task:get_bufnr()
      return task:is_complete()
        and bufnr ~= nil
        and vim.api.nvim_buf_is_valid(bufnr)
        and vim.api.nvim_buf_is_loaded(bufnr)
    end,
    run = function(task)
      local lines = vim.api.nvim_buf_get_lines(assert(task:get_bufnr()), 0, -1, true)
      vim.fn.setqflist({}, " ", {
        title = task.name,
        lines = lines,
        -- Peep into the default component params to fetch the errorformat
        efm = task.default_component_params.errorformat,
      })
      vim.cmd("botright copen")
    end,
  },
}

return M
