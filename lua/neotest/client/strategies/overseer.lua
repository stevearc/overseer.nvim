local async = require("neotest.async")
local lib = require("neotest.lib")
local overseer = require("overseer")

if not overseer.component.get_alias("default_neotest") then
  overseer.component.alias("default_neotest", { "default" })
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
  opts.cmd = spec.command
  opts.env = spec.env
  opts.cwd = spec.cwd
  local task = overseer.new_task(opts)
  task:set_include_in_bundle(false)
  task:subscribe("on_complete", function()
    finish_cond:notify_all()
  end)
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
    output_stream = function()
      local sender, receiver = async.control.channel.mpsc()
      task:subscribe("on_output", function(_, data)
        sender.send(table.concat(data, "\n"))
      end)
      return function()
        return async.lib.first(function()
          finish_cond:wait()
        end, receiver.recv)
      end
    end,
    attach = function()
      local bufnr = task:get_bufnr()
      if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      attach_win = lib.ui.float.open({
        height = spec.strategy.height,
        width = spec.strategy.width,
        buffer = bufnr,
      })
      async.api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
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
