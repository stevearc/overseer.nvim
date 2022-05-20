local config = require("overseer.config")
local constants = require("overseer.constants")
local registry = require("overseer.registry")
local util = require("overseer.util")
local STATUS = constants.STATUS
local SLOT = constants.SLOT
local M = {}

local TaskList = {}

local ref

M.get_or_create = function()
  if not ref then
    ref = TaskList.new()
  end
  return ref
end

local MIN_DETAIL = 0
local MAX_DETAIL = 3

function TaskList.new()
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  local tl = setmetatable({
    bufnr = bufnr,
    default_detail = 1,
    task_detail = {},
    actions = {
      {
        name = "start",
        condition = function(task)
          return task.status == STATUS.PENDING
        end,
        callback = function(task)
          task:start()
        end,
      },
      {
        name = "stop",
        condition = function(task)
          return task.status == STATUS.RUNNING
        end,
        callback = function(task)
          task:stop()
        end,
      },
      {
        name = "rerun",
        condition = function(task)
          return task:has_component("rerun_trigger")
            and task.status ~= STATUS.PENDING
            and task.status ~= STATUS.RUNNING
        end,
        callback = function(task)
          task:rerun()
        end,
      },
      {
        name = "dispose",
        condition = function(task)
          return true
        end,
        callback = function(task)
          task:dispose(true)
        end,
      },
      {
        name = "rerun on save",
        condition = function(task)
          return task:has_component("rerun_trigger") and not task:has_component("rerun_on_save")
        end,
        callback = function(task)
          vim.ui.input({
            prompt = "Directory (files saved here will trigger rerun)",
            default = vim.fn.getcwd(0),
          }, function(dirname)
            task:remove_by_slot(SLOT.DISPOSE)
            local trigger = task:get_component("rerun_trigger")
            if trigger and not trigger.params.interrupt then
              task:remove_component("rerun_trigger")
            end
            task:add_component({ "rerun_trigger", interrupt = true })
            task:add_component({ "rerun_on_save", dirname = dirname })
            registry.update_task(task)
          end)
        end,
      },
    },
    task_lines = {},
  }, { __index = TaskList })

  vim.api.nvim_create_autocmd({ "BufHidden", "WinLeave" }, {
    desc = "Close preview window when task list closes",
    buffer = bufnr,
    command = "pclose",
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    desc = "Clean up references on buffer unload",
    buffer = bufnr,
    callback = function()
      ref = nil
    end,
    once = true,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    desc = "Update preview window when cursor moves",
    buffer = bufnr,
    callback = function()
      tl:update_preview()
    end,
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
    callback = function()
      tl:run_action()
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "o", "", {
    callback = function()
      tl:open_buffer()
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "p", "", {
    callback = function()
      tl:toggle_preview()
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "l", "", {
    callback = function()
      tl:change_task_detail(1)
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "h", "", {
    callback = function()
      tl:change_task_detail(-1)
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "L", "", {
    callback = function()
      tl:change_default_detail(1)
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "H", "", {
    callback = function()
      tl:change_default_detail(-1)
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "[", "", {
    callback = function()
      local width = vim.api.nvim_win_get_width(0)
      vim.api.nvim_win_set_width(0, math.max(10, width - 10))
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "]", "", {
    callback = function()
      local width = vim.api.nvim_win_get_width(0)
      vim.api.nvim_win_set_width(0, width + 10)
    end,
  })

  ref = tl
  return tl
end

function TaskList:register_action(opts)
  vim.validate({
    name = { opts.name, "s" },
    condition = { opts.condition, "f" },
    callback = { opts.callback, "f" },
  })
  table.insert(self.actions, opts)
end

function TaskList:_get_task_from_line(lnum)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  -- TODO could do binary search here
  for _, v in ipairs(self.task_lines) do
    if v[1] > lnum then
      return v[2]
    end
  end
end

function TaskList:toggle_preview()
  local pwin = util.get_preview_window()
  if pwin then
    vim.cmd([[pclose]])
    return
  end
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
    return
  end

  local bufname = vim.api.nvim_buf_get_name(task.bufnr)
  vim.cmd(string.format("vertical pedit %s", bufname))
  local winid = util.get_preview_window()
  if winid then
    util.scroll_to_end(winid)
  end
end

function TaskList:change_task_detail(delta)
  local task = self:_get_task_from_line()
  if not task then
    return
  end
  local detail = self.task_detail[task.id] or self.default_detail
  self.task_detail[task.id] = math.max(MIN_DETAIL, math.min(MAX_DETAIL, detail + delta))
  registry.update_task(task)
end

function TaskList:change_default_detail(delta)
  self.default_detail = math.max(MIN_DETAIL, math.min(MAX_DETAIL, self.default_detail + delta))
  for i, v in pairs(self.task_detail) do
    if (delta < 0 and v > self.default_detail) or (delta > 0 and v < self.default_detail) then
      self.task_detail[i] = nil
    end
  end
  registry.update()
end

function TaskList:update_preview()
  local winid = util.get_preview_window()
  if not winid then
    return
  end
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
    return
  end

  local task_buf_name = vim.api.nvim_buf_get_name(task.bufnr)
  local winbuf = vim.api.nvim_win_get_buf(winid)
  local preview_buf_name = vim.api.nvim_buf_get_name(winbuf)
  if task_buf_name ~= preview_buf_name then
    vim.cmd(string.format("vertical pedit %s", task_buf_name))
    util.scroll_to_end(winid)
  end
end

function TaskList:open_buffer()
  local task = self:_get_task_from_line()
  if not task or not task.bufnr or not vim.api.nvim_buf_is_valid(task.bufnr) then
    return
  end

  vim.cmd([[normal! m']])
  vim.api.nvim_win_set_buf(0, task.bufnr)
  util.scroll_to_end(0)
end

function TaskList:run_action(name)
  vim.validate({ name = { name, "s", true } })
  local task = self:_get_task_from_line()
  if not task then
    return
  end

  local actions = {}
  for _, action in ipairs(self.actions) do
    if action.condition(task, self) then
      if action.name == name then
        action.callback(task, self)
        registry.update_task(task)
        return
      end
      table.insert(actions, action)
    end
  end
  if name then
    vim.notify(string.format("No action '%s' found for task", name), vim.log.levels.ERROR)
    return
  end

  vim.ui.select(actions, {
    prompt = "Task actions",
    kind = "overseer_task_options",
    format_item = function(action)
      return action.name
    end,
  }, function(action)
    if action then
      if action.condition(task, self) then
        action.callback(task, self)
        registry.update_task(task)
      else
        vim.notify(
          string.format("Can no longer perform action '%s' on task", action.name),
          vim.log.levels.WARN
        )
      end
    end
  end)
end

function TaskList:render(tasks)
  if not vim.api.nvim_buf_is_valid(self.bufnr) then
    return false
  end
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)

  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  local lines = {}
  local highlights = {}
  local lineno = 1
  self.task_lines = {}
  -- Iterate backwards so we should most recent tasks first
  for i = #tasks, 1, -1 do
    local task = tasks[i]
    local detail = self.task_detail[task.id] or self.default_detail
    lineno = lineno + task:render(lines, highlights, detail)
    table.insert(self.task_lines, { lineno, task })
    if i > 1 then
      table.insert(lines, config.list_sep)
      table.insert(highlights, { "OverseerTaskBorder", #lines, 0, -1 })
      lineno = lineno + 1
    end
  end
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(self.bufnr, "modified", false)
  for _, hl in ipairs(highlights) do
    local group, row, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(self.bufnr, ns, group, row - 1, col_start, col_end)
  end

  return true
end

M.new = TaskList.new

M.register_action = function(...)
  local tl = M.get_or_create()
  tl:register_action(...)
end

return M
