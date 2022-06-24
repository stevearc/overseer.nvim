local constants = require("overseer.constants")
local layout = require("overseer.layout")
local task_bundle = require("overseer.task_bundle")
local task_list = require("overseer.task_list")
local task_editor = require("overseer.task_editor")
local util = require("overseer.util")
local STATUS = constants.STATUS

local M

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
  save = {
    desc = "save the task to a bundle file",
    condition = function(task)
      return task:is_serializable()
    end,
    run = function(task)
      task_bundle.save_task_bundle(nil, { task })
    end,
  },
  restart = {
    condition = function(task)
      return task:has_component("on_restart_handler")
        and task.status ~= STATUS.PENDING
        and task.status ~= STATUS.RUNNING
    end,
    run = function(task)
      task:restart()
    end,
  },
  dispose = {
    condition = function(task)
      return true
    end,
    run = function(task)
      task:dispose(true)
    end,
  },
  edit = {
    condition = function(task)
      return task.status ~= STATUS.RUNNING
    end,
    run = function(task)
      task_editor.open(task, function(t)
        if t then
          task_list.update(t)
        end
      end)
    end,
  },
  ensure = {
    desc = "restart the task if it fails",
    condition = function(task)
      return true
    end,
    run = function(task)
      task:add_components({ "on_restart_handler", "on_result_restart" })
      if task.status == STATUS.FAILURE then
        task:restart()
      end
    end,
  },
  watch = {
    desc = "restart the task when you save a file",
    condition = function(task)
      return task:has_component("on_restart_handler") and not task:has_component("restart_on_save")
    end,
    run = function(task)
      vim.ui.input({
        prompt = "Directory (watch these files)",
        completion = "file",
        default = vim.fn.getcwd(0),
      }, function(dir)
        task:set_components({
          { "on_restart_handler", interrupt = true },
          { "restart_on_save", dir = dir },
        })
        task_list.update(task)
      end)
    end,
  },
  ["open float"] = {
    desc = "open terminal in a floating window",
    condition = function(task)
      return task.bufnr and vim.api.nvim_buf_is_valid(task.bufnr)
    end,
    run = function(task)
      layout.open_fullscreen_float(task.bufnr)
    end,
  },
  open = {
    desc = "open terminal in the current window",
    condition = function(task)
      return task.bufnr and vim.api.nvim_buf_is_valid(task.bufnr)
    end,
    run = function(task)
      vim.cmd([[normal! m']])
      vim.api.nvim_win_set_buf(0, task.bufnr)
    end,
  },
  ["open vsplit"] = {
    desc = "open terminal in a vertical split",
    condition = function(task)
      return task.bufnr and vim.api.nvim_buf_is_valid(task.bufnr)
    end,
    run = function(task)
      vim.cmd([[vsplit]])
      vim.api.nvim_win_set_buf(0, task.bufnr)
    end,
  },
  ["set quickfix diagnostics"] = {
    desc = "put the diagnostics results into quickfix",
    condition = function(task)
      return task.result
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
      return task.result
        and task.result.diagnostics
        and not vim.tbl_isempty(task.result.diagnostics)
    end,
    run = function(task)
      local winid = util.find_code_window()
      vim.fn.setloclist(winid, task.result.diagnostics)
    end,
  },
}

return M
