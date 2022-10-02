---@param winid integer
---@return boolean
local function is_cursor_at_bottom(winid)
  if vim.api.nvim_win_is_valid(winid) then
    local lnum = vim.api.nvim_win_get_cursor(winid)[1]
    local bufnr = vim.api.nvim_win_get_buf(winid)
    local num_lines = vim.api.nvim_buf_line_count(bufnr)
    return lnum == num_lines
  end
  return false
end

---@param self table The component
---@param height nil|integer
---@return boolean True if the quickfix window was opened
local function copen(self, height)
  -- Only open the quickfix once. If the user closes it, we don't want to re-open.
  if self.qf_opened then
    return
  end
  local cur_qf = vim.fn.getqflist({ winid = 0, id = self.qf_id })
  local open_cmd = "botright copen"
  if height then
    open_cmd = string.format("%s %d", open_cmd, height)
  end
  local winid = vim.api.nvim_get_current_win()
  vim.cmd(open_cmd)
  vim.api.nvim_set_current_win(winid)
  self.qf_opened = true
  return cur_qf.winid == 0
end

return {
  desc = "Set all task output into the quickfix (on complete)",
  params = {
    errorformat = {
      desc = "See :help errorformat",
      type = "string",
      optional = true,
      default_from_task = true,
    },
    open = {
      desc = "Open the quickfix on output",
      type = "boolean",
      default = false,
    },
    open_on_match = {
      desc = "Open the quickfix when the errorformat finds a match",
      type = "boolean",
      default = false,
    },
    open_height = {
      desc = "The height of the quickfix when opened",
      type = "integer",
      optional = true,
      validate = function(v)
        return v > 0
      end,
    },
    close = {
      desc = "Close the quickfix on completion if no errorformat matches",
      type = "boolean",
      default = false,
    },
    items_only = {
      desc = "Only show lines that match the errorformat",
      type = "boolean",
      default = false,
    },
    set_diagnostics = {
      desc = "Add the matching items to vim.diagnostics",
      type = "boolean",
      default = false,
    },
    tail = {
      desc = "Update the quickfix with task output as it happens, instead of waiting until completion",
      long_desc = 'This may cause unexpected results for commands that produce "fancy" output using terminal escape codes (e.g. animated progress indicators)',
      type = "boolean",
      default = true,
    },
  },
  constructor = function(params)
    local comp = {
      qf_id = 0,
      qf_opened = false,
      on_reset = function(self, task)
        self.qf_id = 0
        self.qf_opened = false
      end,
      on_pre_result = function(self, task)
        local lines = vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, true)
        local prev_context = vim.fn.getqflist({ context = 0 }).context
        local action = " "
        -- If we have a quickfix ID, or if the current QF has a matching context, replace the list
        -- instead of creating a new one
        if prev_context == task.id or self.qf_id ~= 0 then
          action = "r"
        end
        local items = vim.fn.getqflist({
          lines = lines,
          efm = params.errorformat,
        }).items
        local valid_items = vim.tbl_filter(function(item)
          return item.valid == 1
        end, items)
        if params.items_only then
          items = valid_items
        end

        local what = {
          title = task.name,
          context = task.id,
          items = items,
        }
        if self.qf_id ~= 0 then
          what.id = self.qf_id
        end
        vim.fn.setqflist({}, action, what)

        if vim.tbl_isempty(valid_items) then
          if params.close then
            vim.cmd("cclose")
          elseif params.open then
            copen(self, params.open_height)
          end
        elseif params.open_on_match or params.open then
          copen(self, params.open_height)
        end

        if params.set_diagnostics then
          return {
            diagnostics = items,
          }
        end
      end,
    }

    if params.tail then
      comp.on_output_lines = function(self, task, lines)
        local cur_qf = vim.fn.getqflist({ context = 0, winid = 0, id = self.qf_id })
        local action = " "
        if cur_qf.context == task.id then
          -- qf_id is 0 after a restart. If we're restarting; replace the contents of the list.
          -- Otherwise append.
          action = self.qf_id == 0 and "r" or "a"
        end
        local scroll_buffer = action ~= "a" or is_cursor_at_bottom(cur_qf.winid)
        local items = vim.fn.getqflist({
          lines = lines,
          efm = params.errorformat,
        }).items
        local valid_items = vim.tbl_filter(function(item)
          return item.valid == 1
        end, items)
        if params.items_only then
          items = valid_items
        end
        if params.open or (not vim.tbl_isempty(valid_items) and params.open_on_match) then
          scroll_buffer = scroll_buffer or copen(self, params.open_height)
          cur_qf = vim.fn.getqflist({ context = 0, winid = 0, id = self.qf_id })
        end
        local what = {
          title = task.name,
          context = task.id,
          items = items,
        }
        if action == "a" then
          -- Only pass the ID if appending to existing list
          what.id = self.qf_id
        end
        vim.fn.setqflist({}, action, what)
        -- Store the quickfix list ID if we don't have one yet
        if self.qf_id == 0 then
          self.qf_id = vim.fn.getqflist({ id = 0 }).id
        end
        if scroll_buffer and cur_qf.winid ~= 0 and vim.api.nvim_win_is_valid(cur_qf.winid) then
          local bufnr = vim.api.nvim_win_get_buf(cur_qf.winid)
          local num_lines = vim.api.nvim_buf_line_count(bufnr)
          vim.api.nvim_win_set_cursor(cur_qf.winid, { num_lines, 0 })
        end
      end
    end
    return comp
  end,
}
