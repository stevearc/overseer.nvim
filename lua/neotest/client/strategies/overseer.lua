local async = require("neotest.async")
local lib = require("neotest.lib")
local log = require("overseer.log")
local overseer = require("overseer")
local util = require("overseer.util")

local M = {}

local current_group_id = 0
local tasks_by_group = {}
local pool = {}

---@param group_id integer
M.set_group_id = function(group_id)
  current_group_id = group_id
end

---@param group_id integer
M.recycle_group = function(group_id)
  if not pool[group_id] then
    pool[group_id] = {}
  end
  log:debug("Recycling neotest task group %s", group_id)
  vim.list_extend(pool[group_id], tasks_by_group[group_id])
  tasks_by_group[group_id] = {}
end

local function get_or_create_task(spec, output_path)
  local recycled = pool[current_group_id]
  local task
  -- Get the first non-disposed task in the recycled pool
  while not task and recycled and not vim.tbl_isempty(recycled) do
    task = table.remove(recycled)
    if task:is_disposed() then
      task = nil
    end
  end
  if task then
    -- Reset the task
    log:debug("Using pooled neotest task %s from group %s", task.id, current_group_id)
    task:reset(false)
    task:remove_components({ "on_output_write_file", "neotest.link_with_neotest" })
    task:add_components({
      { "on_output_write_file", filename = output_path },
      "neotest.link_with_neotest",
    })
    task.cmd = spec.command
    task.env = spec.env
    task.cwd = spec.cwd
  else
    -- Create a new task
    local opts = vim.tbl_extend("keep", spec.strategy or {}, {
      name = "Neotest",
      components = { "default_neotest" },
    })
    vim.list_extend(
      opts.components,
      { { "on_output_write_file", filename = output_path }, "neotest.link_with_neotest" }
    )
    opts.cmd = spec.command
    opts.env = spec.env
    opts.cwd = spec.cwd
    opts.metadata = {
      neotest_group_id = current_group_id,
    }
    task = overseer.new_task(opts)
    log:debug("Created new neotest task %s group %s", task.id, current_group_id)
    task:set_include_in_bundle(false)
    task:subscribe("on_dispose", function(disposed_task)
      local tasks = tasks_by_group[disposed_task.metadata.group_id]
      if tasks then
        util.tbl_remove(tasks, disposed_task)
      end
    end)
  end
  if not tasks_by_group[current_group_id] then
    tasks_by_group[current_group_id] = {}
  end
  table.insert(tasks_by_group[current_group_id], task)
  return task
end

local function get_strategy(spec)
  if not overseer.component.get_alias("default_neotest") then
    overseer.component.alias("default_neotest", { "default" })
  end

  local finish_cond = async.control.Condvar.new()
  local attach_win
  local output_path = async.fn.tempname()
  local task = get_or_create_task(spec, output_path)
  task:subscribe("on_complete", function()
    finish_cond:notify_all()
    return false
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

return setmetatable(M, {
  __call = function(_, ...)
    return get_strategy(...)
  end,
})
