local constants = require("overseer.constants")
local files = require("overseer.files")
local registry = require("overseer.registry")
local task_editor = require("overseer.task_editor")
local STATUS = constants.STATUS
local SLOT = constants.SLOT

local M = {
  start = {
    condition = function(task)
      return task.status == STATUS.PENDING
    end,
    callback = function(task)
      task:start()
    end,
  },
  stop = {
    condition = function(task)
      return task.status == STATUS.RUNNING
    end,
    callback = function(task)
      task:stop()
    end,
  },
  save = {
    description = "save the task to a bundle file",
    condition = function(task)
      return true
    end,
    callback = function(task)
      local data = task:serialize()
      vim.ui.input({
        prompt = "Task bundle name:",
      }, function(selected)
        if selected then
          local filename = string.format("%s.bundle.json", selected)
          files.write_data_file(filename, { data })
        end
      end)
    end,
  },
  rerun = {
    condition = function(task)
      return task:has_component("rerun_trigger")
        and task.status ~= STATUS.PENDING
        and task.status ~= STATUS.RUNNING
    end,
    callback = function(task)
      task:rerun()
    end,
  },
  dispose = {
    condition = function(task)
      return true
    end,
    callback = function(task)
      task:dispose(true)
    end,
  },
  edit = {
    condition = function(task)
      return task.status ~= STATUS.RUNNING
    end,
    callback = function(task)
      task_editor.open(task, function(t)
        if t then
          registry.update_task(t)
        end
      end)
    end,
  },
  ensure = {
    description = "rerun the task if it fails",
    condition = function(task)
      return true
    end,
    callback = function(task)
      task:add_components({ "rerun_trigger", "rerun_on_result" })
      if task.status == STATUS.FAILURE then
        task:rerun()
      end
    end,
  },
  watch = {
    description = "rerun the task when you save a file",
    condition = function(task)
      return task:has_component("rerun_trigger") and not task:has_component("rerun_on_save")
    end,
    callback = function(task)
      vim.ui.input({
        prompt = "Directory (watch these files)",
        default = vim.fn.getcwd(0),
      }, function(dir)
        task:remove_by_slot(SLOT.DISPOSE)
        task:set_components({
          { "rerun_trigger", interrupt = true },
          { "rerun_on_save", dir = dir },
        })
        registry.update_task(task)
      end)
    end,
  },
}

return M
