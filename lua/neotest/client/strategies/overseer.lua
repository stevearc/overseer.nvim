local async = require("neotest.async")
local lib = require("neotest.lib")
local overseer = require("overseer")

overseer.component.register({
  name = "on_status_callback",
  description = "Call a callback when complete",
  editable = false,
  serialize = "fail",
  params = {
    callback = { type = "opaque" },
  },
  constructor = function(params)
    return {
      on_result = function(self, task, status)
        if task:is_complete() then
          params.callback(status)
        end
      end,
    }
  end,
})

if not overseer.component.get_alias("default_neotest") then
  overseer.component.alias("default_neotest", "default")
end

return function(spec)
  local finish_cond = async.control.Condvar.new()
  local attach_win
  local output_path = async.fn.tempname()
  local opts = vim.tbl_extend("keep", spec.strategy or {}, {
    name = "Neotest",
    components = { "default_neotest" },
  })
  table.insert(opts.components, { "on_output_write_file", filename = output_path })
  table.insert(opts.components, {
    "on_status_callback",
    callback = function()
      finish_cond:notify_all()
    end,
  })
  opts.cmd = spec.command
  opts.env = spec.env
  opts.cwd = spec.cwd
  local task = overseer.new_task(opts)
  task:start()
  return {
    is_complete = function()
      return task:is_complete()
    end,
    output = function()
      return output_path
    end,
    stop = function()
      task:stop()
    end,
    attach = function()
      if not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
        return
      end
      attach_win = lib.ui.float.open({
        height = spec.strategy.height,
        width = spec.strategy.width,
        buffer = task.bufnr,
      })
      async.api.nvim_buf_set_keymap(task.bufnr, "n", "q", "", {
        noremap = true,
        silent = true,
        callback = function()
          pcall(vim.api.nvim_win_close, attach_win.win_id, true)
        end,
      })
      attach_win:jump_to()
    end,
    result = function()
      if not task:is_complete() then
        finish_cond:wait()
      end
      if attach_win then
        vim.schedule(function()
          attach_win:close(true)
        end)
      end
      return task.exit_code
    end,
  }
end
