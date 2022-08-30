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
    run = function(task)
      task_bundle.save_task_bundle(nil, { task })
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
    condition = function(task)
      -- Only allow editing tasks with the terminal strategy for now
      return task.status ~= STATUS.RUNNING and task.strategy.name == "terminal"
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
      vim.ui.input({
        prompt = "Directory (watch these files)",
        completion = "file",
        default = vim.fn.getcwd(0),
      }, function(dir)
        task:set_components({
          -- TODO prompt for "interrupt" too
          { "restart_on_save", dir = dir },
        })
        task_list.update(task)
      end)
    end,
  },
  ["open float"] = {
    desc = "open terminal in a floating window",
    condition = function(task)
      local bufnr = task:get_bufnr()
      return bufnr and vim.api.nvim_buf_is_valid(bufnr)
    end,
    run = function(task)
      layout.open_fullscreen_float(task:get_bufnr())
    end,
  },
  open = {
    desc = "open terminal in the current window",
    condition = function(task)
      local bufnr = task:get_bufnr()
      return bufnr and vim.api.nvim_buf_is_valid(bufnr)
    end,
    run = function(task)
      vim.cmd([[normal! m']])
      vim.api.nvim_win_set_buf(0, task:get_bufnr())
    end,
  },
  ["open hsplit"] = {
    desc = "open terminal in a horizontal split",
    condition = function(task)
      local bufnr = task:get_bufnr()
      return bufnr and vim.api.nvim_buf_is_valid(bufnr)
    end,
    run = function(task)
      -- If we're currently in the task list, open a split in the nearest other window
      if vim.api.nvim_buf_get_option(0, "filetype") == "OverseerList" then
        for _, winid in ipairs(util.get_fixed_wins()) do
          if not vim.api.nvim_win_get_option(winid, "winfixwidth") then
            util.go_win_no_au(winid)
            break
          end
        end
      end
      vim.cmd([[split]])
      util.set_term_window_opts()
      vim.api.nvim_win_set_buf(0, task:get_bufnr())
    end,
  },
  ["open vsplit"] = {
    desc = "open terminal in a vertical split",
    condition = function(task)
      local bufnr = task:get_bufnr()
      return bufnr and vim.api.nvim_buf_is_valid(bufnr)
    end,
    run = function(task)
      vim.cmd([[vsplit]])
      util.set_term_window_opts()
      vim.api.nvim_win_set_buf(0, task:get_bufnr())
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
  ["open output in quickfix"] = {
    desc = "open the entire task output in quickfix",
    condition = function(task)
      local bufnr = task:get_bufnr()
      return task:is_complete()
        and bufnr
        and vim.api.nvim_buf_is_valid(bufnr)
        and vim.api.nvim_buf_is_loaded(bufnr)
    end,
    run = function(task)
      local lines = vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, true)
      vim.fn.setqflist({}, " ", {
        title = task.name,
        context = task.name,
        lines = lines,
      })
      vim.cmd("botright copen")
    end,
  },
}

return M
