local task_list = require("overseer.task_list")

local min_win_opts = {
  number = false,
  relativenumber = false,
  cursorline = false,
  cursorcolumn = false,
  foldcolumn = "0",
  signcolumn = "no",
  spell = false,
  list = false,
}
---@param winid integer
local function set_minimal_win_opts(winid)
  for k, v in pairs(min_win_opts) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = winid })
  end
end

---@class (exact) overseer.TaskViewOpts
---@field select? fun(self: overseer.TaskView, tasks: overseer.Task[], task_under_cursor: overseer.Task?): overseer.Task?
---@field close_on_list_close? boolean Close the window when the task list is closed

---@class overseer.TaskView
---@field winid integer
---@field private select fun(self: overseer.TaskView, tasks: overseer.Task[], task_under_cursor: overseer.Task?): overseer.Task?
---@field private autocmd_ids integer[]
local TaskView = {}

---@param winid integer
---@param opts? overseer.TaskViewOpts
---@return overseer.TaskView
function TaskView.new(winid, opts)
  opts = opts or {}
  if winid == 0 then
    winid = vim.api.nvim_get_current_win()
  end
  set_minimal_win_opts(winid)
  local self = setmetatable({
    winid = winid,
    select = opts.select or function(self, tasks)
      return tasks[1]
    end,
    autocmd_ids = {},
  }, { __index = TaskView })

  -- Create one single autocmd that tracks the task_id under the cursor
  if not TaskView.cursor_track_autocmd_id then
    TaskView.cursor_track_autocmd_id = vim.api.nvim_create_autocmd("User", {
      desc = "Update task view when cursor moves in task list",
      pattern = "OverseerListTaskHover",
      callback = function(args)
        local task_id = args.data.task_id
        TaskView.task_under_cursor = task_id and task_list.get(task_id)
      end,
    })
  end
  -- Create one single autocmd that tracks task list focus
  if not TaskView.focus_autocmd_id then
    TaskView.focus_autocmd_id = vim.api.nvim_create_autocmd("WinEnter", {
      desc = "Track focus on Overseer task list",
      nested = true,
      callback = function()
        vim.api.nvim_exec_autocmds(
          "User",
          { pattern = "OverseerListFocusChanged", modeline = false }
        )
      end,
    })
  end

  table.insert(
    self.autocmd_ids,
    vim.api.nvim_create_autocmd("User", {
      desc = "Update task view when task list changes",
      pattern = "OverseerListUpdate",
      callback = function()
        self:update()
      end,
    })
  )
  if opts.close_on_list_close then
    table.insert(
      self.autocmd_ids,
      vim.api.nvim_create_autocmd("User", {
        desc = "Close task view when task list is closed",
        pattern = "OverseerListClose",
        callback = function()
          self:dispose()
        end,
      })
    )
  end
  table.insert(
    self.autocmd_ids,
    vim.api.nvim_create_autocmd("User", {
      desc = "Update task view when cursor moves in task list",
      pattern = "OverseerListTaskHover",
      callback = function()
        self:update()
      end,
    })
  )
  table.insert(
    self.autocmd_ids,
    vim.api.nvim_create_autocmd("User", {
      desc = "Update task view when focusing the task list",
      pattern = "OverseerListFocusChanged",
      callback = function()
        self:update()
      end,
    })
  )
  self:update()
  return self
end

---@return boolean
function TaskView:is_disposed()
  return not vim.api.nvim_win_is_valid(self.winid)
end

local empty_bufnr = nil
---@return integer
local function get_empty_bufnr()
  if not empty_bufnr or not vim.api.nvim_buf_is_valid(empty_bufnr) then
    empty_bufnr = vim.api.nvim_create_buf(false, true)
    vim.b[empty_bufnr].overseer_task = -1
    vim.api.nvim_buf_set_lines(empty_bufnr, 0, -1, true, { "--no task buffer--" })
    vim.bo[empty_bufnr].bufhidden = "wipe"
  end
  return empty_bufnr
end

function TaskView:update()
  if self:is_disposed() then
    return
  end

  if TaskView.task_under_cursor and TaskView.task_under_cursor:is_disposed() then
    TaskView.task_under_cursor = nil
  end

  local tasks = task_list.list_tasks({ recent_first = true })
  local task = self.select(self, tasks, TaskView.task_under_cursor)
  -- select() function can call dispose()
  if self:is_disposed() then
    return
  end

  local bufnr = task and task:get_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = get_empty_bufnr()
  end

  if bufnr ~= vim.api.nvim_win_get_buf(self.winid) then
    local has_stickybuf, stickybuf = pcall(require, "stickybuf")
    if has_stickybuf then
      stickybuf.unpin(self.winid)
    end
    vim.api.nvim_win_set_buf(self.winid, bufnr)
    set_minimal_win_opts(self.winid)
  end
end

function TaskView:dispose()
  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
  for _, id in ipairs(self.autocmd_ids) do
    vim.api.nvim_del_autocmd(id)
  end
  self.autocmd_ids = {}
end

return TaskView
