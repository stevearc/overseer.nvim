local lib = require("neotest.lib")
local log = require("overseer.log")
local nio = require("nio")
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
  log.debug("Recycling neotest task group %s", group_id)
  vim.list_extend(pool[group_id], tasks_by_group[group_id])
  tasks_by_group[group_id] = {}
end

---@param spec neotest.RunSpec
---@param context neotest.StrategyContext
---@param output_path string
---@return overseer.Task
local function get_or_create_task(spec, context, output_path)
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
    log.debug("Using pooled neotest task %s from group %s", task.id, current_group_id)
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
    local name = "Neotest"
    if context.position and context.position.name then
      name = string.format("%s %s", name, context.position.name)
    end
    local strategy = spec.strategy
    if type(strategy) == "function" then
      strategy = strategy(spec, context)
    end
    local opts = vim.tbl_extend("keep", strategy or {}, {
      name = name,
      components = { "default_neotest" },
    })
    if type(opts.components) == "function" then
      opts.components = opts.components(spec)
    end
    opts.components = vim.list_extend(
      { { "on_output_write_file", filename = output_path }, "neotest.link_with_neotest" },
      opts.components
    )
    opts.cmd = spec.command
    opts.env = spec.env
    opts.cwd = spec.cwd
    opts.metadata = {
      neotest_group_id = current_group_id,
    }
    task = overseer.new_task(opts)
    log.debug("Created new neotest task %s group %s", task.id, current_group_id)
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

---@param spec neotest.RunSpec
---@param context neotest.StrategyContext
---@return neotest.Process
local function get_strategy(spec, context)
  if not overseer.component.get_alias("default_neotest") then
    overseer.component.alias("default_neotest", { "default" })
  end

  local finish_future = nio.control.future()
  local attach_win
  local output_path = nio.fn.tempname()
  local task = get_or_create_task(spec, context, output_path)
  task:subscribe("on_complete", function()
    finish_future.set()
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
    stop = vim.schedule_wrap(function()
      task:stop()
    end),
    output_stream = function()
      local queue = nio.control.queue()
      task:subscribe("on_output", function(_, data)
        queue.put_nowait(table.concat(data, "\n"))
      end)
      return function()
        return nio.first({ finish_future.wait, queue.get })
      end
    end,
    attach = function()
      local bufnr = task:get_bufnr()
      if not bufnr or not nio.api.nvim_buf_is_valid(bufnr) then
        return
      end
      attach_win = lib.ui.float.open({
        height = spec.strategy.height or 40,
        width = spec.strategy.width or 120,
        buffer = bufnr,
      })
      nio.api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
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
        finish_future:wait()
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
